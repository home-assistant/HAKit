internal class HARequestInvocationSingle: HARequestInvocation {
    private var completion: HAConnectionProtocol.RequestCompletion?

    init(
        request: HARequest,
        completion: @escaping HAConnectionProtocol.RequestCompletion
    ) {
        self.completion = completion
        super.init(request: request)
    }

    override func cancel() {
        super.cancel()
        completion = nil
    }

    override var needsAssignment: Bool {
        super.needsAssignment && completion != nil
    }

    func resolve(_ result: Result<HAData, HAError>) {
        // we need to make it impossible to call the completion handler more than once
        completion?(result)
        completion = nil
    }
}
