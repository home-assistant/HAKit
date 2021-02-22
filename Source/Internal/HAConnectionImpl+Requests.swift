extension HAConnectionImpl: HARequestControllerDelegate {
    func requestControllerShouldSendRequests(_ requestController: HARequestController) -> Bool {
        if case .command = responseController.phase {
            return true
        } else {
            return false
        }
    }

    func requestController(
        _ requestController: HARequestController,
        didPrepareRequest request: HARequest,
        with identifier: HARequestIdentifier
    ) {
        var data = request.data
        data["id"] = identifier.rawValue
        data["type"] = request.type.rawValue

        print("sending \(data)")

        sendRaw(data) { _ in
        }
    }
}
