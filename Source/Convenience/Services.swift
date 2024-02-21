public extension HATypedRequest {
    /// Call a service
    ///
    /// - Note: Parameters are `ExpressibleByStringLiteral`. You can use strings instead of using `.init(rawValue:)`.
    /// - Parameters:
    ///   - domain: The domain of the service, e.g. `light`
    ///   - service: The service, e.g. `turn_on`
    ///   - data: The service data
    /// - Returns: A typed request that can be sent via `HAConnection`
    static func callService(
        domain: HAServicesDomain,
        service: HAServicesService,
        data: [String: Any] = [:]
    ) -> HATypedRequest<HAResponseVoid> {
        .init(request: .init(type: .callService, data: [
            "domain": domain.rawValue,
            "service": service.rawValue,
            "service_data": data,
        ]))
    }

    /// Retrieve definition of all services
    ///
    /// - Returns: A typed request that can be sent via `HAConnection`
    static func getServices() -> HATypedRequest<HAResponseServices> {
        .init(request: .init(type: .getServices, data: [:]))
    }
}

/// A service definition
public struct HAServiceDefinition {
    /// The domain of the service, for example `light` in `light.turn_on`
    public var domain: HAServicesDomain
    /// The service, for example `turn_on` in `light.turn_on`
    public var service: HAServicesService
    /// The pair of domain and service, for example `light.turn_on`
    public var domainServicePair: String

    /// The name of the service, for example "Turn On"
    public var name: String
    /// The description of the service
    public var description: String
    /// Available fields of the service call
    public var fields: [String: [String: Any]]

    /// Create with information
    /// - Parameters:
    ///   - domain: The domain
    ///   - service: The service
    ///   - data: The data for the definition
    /// - Throws: If any required keys are missing in the data
    public init(domain: HAServicesDomain, service: HAServicesService, data: HAData) throws {
        try self.init(
            domain: domain,
            service: service,
            name: data.decode("name", fallback: data.decode("description")),
            description: data.decode("description"),
            fields: data.decode("fields")
        )
    }

    /// Create with information
    /// - Parameters:
    ///   - domain: The domain of the service
    ///   - service: The service
    ///   - name: The friendly name of the service
    ///   - description: The description of the service
    ///   - fields: Available fields in the service call
    public init(
        domain: HAServicesDomain,
        service: HAServicesService,
        name: String,
        description: String,
        fields: [String: [String: Any]]
    ) {
        self.domain = domain
        self.service = service
        let domainServicePair = "\(domain.rawValue).\(service.rawValue)"
        self.domainServicePair = domainServicePair
        self.name = name.isEmpty ? domainServicePair : name
        self.description = description
        self.fields = fields
    }
}

/// The services available
public struct HAResponseServices: HADataDecodable {
    /// Create with data
    /// - Parameter data: The data from the server
    /// - Throws: If any required keys are missing
    public init(data: HAData) throws {
        guard case let .dictionary(rawDictionary) = data,
              let dictionary = rawDictionary as? [String: [String: [String: Any]]] else {
            throw HADataError.couldntTransform(key: "get_services_root")
        }

        self.allByDomain = try dictionary.reduce(into: [:]) { domains, domainEntry in
            let domain = HAServicesDomain(rawValue: domainEntry.key)
            domains[domain] = try domainEntry.value.reduce(
                into: [HAServicesService: HAServiceDefinition]()
            ) { services, serviceEntry in
                let service = HAServicesService(rawValue: serviceEntry.key)
                services[service] = try HAServiceDefinition(
                    domain: domain,
                    service: service,
                    data: .dictionary(serviceEntry.value)
                )
            }
        }
    }

    /// All service definitions, divided by domain and then by service
    /// For example, you can access allByDomain["light"]["turn_on"] for the definition of `light.turn_on`
    public var allByDomain: [HAServicesDomain: [HAServicesService: HAServiceDefinition]]
    /// All service definitions, sorted by their `\.domainServicePair`
    public var all: [HAServiceDefinition] {
        allByDomain.values.flatMap(\.values).sorted(by: { a, b in
            a.domainServicePair < b.domainServicePair
        })
    }
}
