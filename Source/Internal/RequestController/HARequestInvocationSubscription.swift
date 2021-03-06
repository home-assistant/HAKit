internal class HARequestInvocationSubscription: HARequestInvocation {
    private var handler: HAResetLock<HAConnection.SubscriptionHandler>
    private var initiated: HAResetLock<HAConnection.SubscriptionInitiatedHandler>

    init(
        request: HARequest,
        initiated: HAConnection.SubscriptionInitiatedHandler?,
        handler: @escaping HAConnection.SubscriptionHandler
    ) {
        self.initiated = .init(value: initiated)
        self.handler = .init(value: handler)
        super.init(request: request)
    }

    override func cancel() {
        super.cancel()
        handler.reset()
        initiated.reset()
    }

    override var needsAssignment: Bool {
        // not initiated, since it is optional
        super.needsAssignment && handler.read() != nil
    }

    override func cancelRequest() -> HATypedRequest<HAResponseVoid>? {
        guard let identifier = identifier else {
            return nil
        }

        return .unsubscribe(identifier)
    }

    func resolve(_ result: Result<HAData, HAError>) {
        initiated.read()?(result)
    }

    func invoke(token: HACancellableImpl, event: HAData) {
        handler.read()?(token, event)
    }
}
