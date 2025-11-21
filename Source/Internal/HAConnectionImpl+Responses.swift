import Starscream

extension HAConnectionImpl: Starscream.WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
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
                HAGlobal.log(.error, "delegate failed to provide access token \(error), bailing")
                disconnect(error: error)
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
        case .auth(.invalid):
            // Authentication failed - disconnect with rejected context to block automatic retries
            HAGlobal.log(.error, "authentication failed with invalid token")
            disconnect(
                context: .rejected,
                error: HAError.internal(debugDescription: "authentication failed, invalid token")
            )
        case .auth:
            // we send auth token pre-emptively, so we don't need to care about the other auth messages
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
                HAGlobal.log(.error, "unable to find subscription for identifier \(identifier)")
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
                HAGlobal.log(.error, "unable to find request for identifier \(identifier)")
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
                disconnect(error: error)
            }
            requestController.resetActive()
        }
    }
}
