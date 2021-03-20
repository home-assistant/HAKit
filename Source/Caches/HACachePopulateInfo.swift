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
        let nonRetryRequest: HATypedRequest<IncomingType> = {
            var updated = request
            updated.request.shouldRetry = false
            return updated
        }()
        self.init { connection, perform in
            connection.send(nonRetryRequest, completion: { result in
                guard let incoming = try? result.get() else { return }
                perform { current in
                    transform(.init(incoming: incoming, current: current))
                }
            })
        }
    }

    typealias StartHandler = (HAConnection, @escaping ((OutgoingType?) -> OutgoingType) -> Void) -> HACancellable

    /// Type-erasing block to perform the populate and its transform
    internal let start: StartHandler

    /// Create with a start block
    ///
    /// Only really useful in unit tests to avoid setup.
    ///
    /// - Parameter start: The start block
    internal init(start: @escaping StartHandler) {
        self.start = start
    }
}
