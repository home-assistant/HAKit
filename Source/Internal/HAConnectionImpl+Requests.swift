extension HAConnectionImpl: HARequestControllerDelegate {
    func requestControllerAllowedSendKinds(
        _ requestController: HARequestController
    ) -> HARequestControllerAllowedSendKind {
        switch responseController.phase {
        case .auth, .disconnected: return .rest
        case .command: return [.webSocket, .rest]
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
