/// The domain of a service
///
/// For example, `light` in `light.turn_on` is the domain.
public struct HAServicesDomain: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    /// The domain as a string
    public var rawValue: String
    /// Construct a service domain from a raw value
    /// - Parameter rawValue: The raw value
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Construct a service domain from a literal
    ///
    /// This is mainly useful when stringly-calling a parameter that takes this type.
    /// You should use the `HAServicesDomain.init(rawValue:)` initializer instead.
    ///
    /// - Parameter value: The literal value
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}

/// The service itself in a service call
///
/// Many services can be used on multiple domains, but you should consult the full results to see which are available.
///
/// For example, `turn_on` in `light.turn_on` is the service.
public struct HAServicesService: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    /// The service as a string
    public var rawValue: String
    /// Construct a service from a raw value
    /// - Parameter rawValue: The raw value
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Construct a service from a literal
    ///
    /// This is mainly useful when stringly-calling a parameter that takes this type.
    /// You should use the `HAServicesService.init(rawValue:)` initializer instead.
    ///
    /// - Parameter value: The literal value
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}
