internal class HARequestInvocationSingle: HARequestInvocation {
    private var completion: HAResetLock<HAConnection.RequestCompletion>

    init(
        request: HARequest,
        completion: @escaping HAConnection.RequestCompletion
    ) {
        self.completion = .init(value: completion)
        super.init(request: request)
    }

    override func cancel() {
        super.cancel()
        completion.reset()
    }

    override var needsAssignment: Bool {
        super.needsAssignment && completion.read() != nil
    }

    func resolve(_ result: Result<HAData, HAError>) {
        completion.pop()?(result)
    }
}
