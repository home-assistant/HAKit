extension HAConnectionImpl: HARequestControllerDelegate {
    func requestControllerShouldSendRequests(_ requestController: HARequestController) -> Bool {
        switch responseController.phase {
        case .auth, .disconnected: return false
        case .command: return true
        }
    }

    func requestController(
        _ requestController: HARequestController,
        didPrepareRequest request: HARequest,
        with identifier: HARequestIdentifier
    ) {
        sendRaw(identifier: identifier, request: request)
    }
}
