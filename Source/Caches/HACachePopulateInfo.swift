/// Information about the populate call in the cache
///
/// This is issued in a few situations:
///   1. To initially populate the cache value for the first to-the-cache subscription
///   2. To update the value when reconnecting after having been disconnected
///   3. When a subscribe handler says that it needs to re-execute the populate to get a newer value
public struct HACachePopulateInfo<OutgoingType> {
    /// Create the information for populate
    /// - Parameters:
    ///   - request: The request to perform
    ///   - transform: The handler to convert the request's result into the cache's value type
    public init<IncomingType: HADataDecodable>(
        request: HATypedRequest<IncomingType>,
        transform: @escaping (HACacheTransformInfo<IncomingType, OutgoingType?>) -> OutgoingType
    ) {
        let retryRequest: HATypedRequest<IncomingType> = {
            var updated = request
            updated.request.shouldRetry = true
            return updated
        }()
        self.init(
            request: request.request,
            anyTransform: { possibleValue in
                guard let value = possibleValue as? HACacheTransformInfo<IncomingType, OutgoingType?> else {
                    throw TransformError.incorrectType(
                        have: String(describing: possibleValue),
                        expected: String(describing: IncomingType.self)
                    )
                }

                return transform(value)
            }, start: { connection, perform in
                connection.send(retryRequest, completion: { result in
                    perform { current in
                        transform(.init(incoming: try result.get(), current: current))
                    }
                })
            }
        )
    }

    /// The untyped request that underlies the request that created this info
    /// - Important: This is intended to be used exclusively for writing tests; this method is not called by the cache.
    public let request: HARequest

    /// Error during transform attempt
    public enum TransformError: Error {
        /// The provided type information didn't match what this info was created with
        case incorrectType(have: String, expected: String)
    }

    /// Attempt to replicate the transform provided during initialization
    ///
    /// Since we erase away the incoming type, you need to provide this hinted with a type when executing this block.
    ///
    /// - Important: This is intended to be used exclusively for writing tests; this method is not called by the cache.
    /// - Parameters:
    ///   - incoming: The incoming value, of some given type -- intended to be the IncomingType that created this
    ///   - current: The current value part of the transform info
    /// - Throws: If the type of incoming does not match the original IncomingType
    /// - Returns: The transformed incoming value
    public func transform<IncomingType>(incoming: IncomingType, current: OutgoingType?) throws -> OutgoingType {
        try anyTransform(HACacheTransformInfo<IncomingType, OutgoingType?>(incoming: incoming, current: current))
    }

    /// The start handler
    typealias StartHandler = (HAConnection, @escaping ((OutgoingType?) throws -> OutgoingType) -> Void) -> HACancellable

    /// Type-erasing block to perform the populate and its transform
    internal let start: StartHandler

    /// Helper to allow writing tests around the struct value
    internal var anyTransform: (Any) throws -> OutgoingType

    /// Create with a start block
    ///
    /// Only really useful in unit tests to avoid setup.
    ///
    /// - Parameters:
    ///   - request: The untyped request this was created with
    ///   - anyTransform: The transform to provide for testing this value
    ///   - start: The start block
    internal init(
        request: HARequest,
        anyTransform: @escaping (Any) throws -> OutgoingType,
        start: @escaping StartHandler
    ) {
        self.request = request
        self.anyTransform = anyTransform
        self.start = start
    }
}
