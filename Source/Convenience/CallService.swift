public extension HATypedRequest {
    /// Call a service
    ///
    /// - Parameters:
    ///   - domain: The domain of the service, e.g. `light`
    ///   - service: The service, e.g. `turn_on`
    ///   - data: The service data
    /// - Returns: A typed request that can be sent via `HAConnection`
    static func callService(
        domain: String,
        service: String,
        data: [String: Any] = [:]
    ) -> HATypedRequest<HAResponseVoid> {
        .init(request: .init(type: .callService, data: [
            "domain": domain,
            "service": service,
            "service_data": data,
        ]))
    }
}
