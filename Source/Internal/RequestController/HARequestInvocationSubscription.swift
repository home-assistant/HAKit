internal class HARequestInvocationSubscription: HARequestInvocation {
    private var handler: HAConnectionProtocol.SubscriptionHandler?
    private var initiated: HAConnectionProtocol.SubscriptionInitiatedHandler?

    init(
        request: HARequest,
        initiated: HAConnectionProtocol.SubscriptionInitiatedHandler?,
        handler: @escaping HAConnectionProtocol.SubscriptionHandler
    ) {
        self.initiated = initiated
        self.handler = handler
        super.init(request: request)
    }

    override func cancel() {
        super.cancel()
        handler = nil
        initiated = nil
    }

    override var needsAssignment: Bool {
        super.needsAssignment && handler != nil
    }

    override func cancelRequest() -> HATypedRequest<HAResponseVoid>? {
        if let identifier = identifier {
            return .unsubscribe(identifier)
        } else {
            return nil
        }
    }

    func resolve(_ result: Result<HAData, HAError>) {
        initiated?(result)
    }

    func invoke(token: HACancellableImpl, event: HAData) {
        handler?(token, event)
    }
}
