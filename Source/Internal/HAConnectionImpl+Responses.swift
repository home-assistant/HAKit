import Starscream

extension HAConnectionImpl: Starscream.WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        responseController.didReceive(event: event)
    }
}

extension HAConnectionImpl {
    private func sendAuthToken() {
        let lock = HAResetLock<(Result<String, Error>) -> Void> { [self] result in
            switch result {
            case let .success(token):
                sendRaw(
                    identifier: nil,
                    request: .init(type: .auth, data: ["access_token": token])
                )
            case let .failure(error):
                HAGlobal.log("delegate failed to provide access token \(error), bailing")
                disconnect(permanently: false, error: error)
            }
        }

        configuration.fetchAuthToken { result in
            lock.pop()?(result)
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
                HAGlobal.log("unable to find subscription for identifier \(identifier)")
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
        didTransitionTo phase: HAResponseControllerPhase
    ) {
        switch phase {
        case .auth:
            sendAuthToken()
            notifyState()
        case .command:
            reconnectManager.didFinishConnect()
            requestController.prepare()
            notifyState()
        case let .disconnected(error, forReset: reset):
            if !reset {
                // state will notify from this method call
                disconnect(permanently: false, error: error)
            }
            requestController.resetActive()
        }
    }
}
