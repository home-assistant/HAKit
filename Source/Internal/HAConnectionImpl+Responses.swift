import Starscream

extension HAConnectionImpl: Starscream.WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        responseController.didReceive(event: event)
    }
}

extension HAConnectionImpl {
    private func sendAuthToken() {
        configuration.fetchAuthToken { [self] result in
            switch result {
            case let .success(token):
                sendRaw([
                    "type": "auth",
                    "access_token": token,
                ], completion: { result in
                    switch result {
                    case .success: HAGlobal.log("auth token sent")
                    case let .failure(error):
                        HAGlobal.log("couldn't send auth token \(error), disconnecting")
                        disconnectTemporarily()
                    }
                })
            case let .failure(error):
                HAGlobal.log("delegate failed to provide access token \(error), bailing")
                disconnectTemporarily()
            }
        }
    }
}

extension HAConnectionImpl: HAResponseControllerDelegate {
    func responseController(
        _ responseController: HAResponseController,
        didReceive response: HAWebSocketResponse
    ) {
        switch response {
        case .auth:
            // we send auth token pre-emptively, so we don't need to care about the messages for auth
            // note that we do watch for auth->command phase change so we can re-activate pending requests
            break
        case let .event(identifier: identifier, data: data):
            if let subscription = requestController.subscription(for: identifier) {
                callbackQueue.async { [self] in
                    subscription.invoke(token: HACancellableImpl { [requestController] in
                        requestController.cancel(subscription)
                    }, event: data)
                }
            } else {
                HAGlobal.log("unable to find registration for event identifier \(identifier)")
                send(.unsubscribe(identifier), completion: { _ in })
            }
        case let .result(identifier: identifier, result: result):
            if let request = requestController.single(for: identifier) {
                callbackQueue.async {
                    request.resolve(result)
                }

                requestController.clear(invocation: request)
            } else if let subscription = requestController.subscription(for: identifier) {
                callbackQueue.async {
                    subscription.resolve(result)
                }
            } else {
                HAGlobal.log("unable to find request for identifier \(identifier)")
            }
        }
    }

    func responseController(
        _ responseController: HAResponseController,
        didTransitionTo phase: HAResponseController.Phase
    ) {
        switch phase {
        case .auth: sendAuthToken()
        case .command: requestController.prepare()
        case .disconnected: requestController.resetActive()
        }

        delegate?.connection(self, transitionedTo: state)
    }
}
