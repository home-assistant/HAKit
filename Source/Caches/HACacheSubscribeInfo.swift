/// Information about the subscriptions used to keep the cache up-to-date
public struct HACacheSubscribeInfo<OutgoingType> {
    /// The response to a subscription event
    public enum Response {
        /// Does not require any changes
        case ignore
        /// Issue the populate call again to get a newer value
        case reissuePopulate
        /// Replace the current cache value with this new one
        case replace(OutgoingType)
    }

    /// Create the information for subscription
    /// - Parameters:
    ///   - subscription: The subscription to perform after populate completes
    ///   - transform: The handler to convert the subscription's handler type into the cache's value
    public init<IncomingType: HADataDecodable>(
        subscription: HATypedSubscription<IncomingType>,
        transform: @escaping (HACacheTransformInfo<IncomingType, OutgoingType>) -> Response
    ) {
        let nonRetrySubscription: HATypedSubscription<IncomingType> = {
            var updated = subscription
            updated.request.shouldRetry = false
            return updated
        }()

        self.init { connection, perform in
            connection.subscribe(to: nonRetrySubscription, handler: { _, incoming in
                perform { current in
                    transform(.init(incoming: incoming, current: current))
                }
            })
        }
    }

    typealias StartHandler = (HAConnection, @escaping ((OutgoingType) -> Response) -> Void) -> HACancellable

    /// Type-erasing block to perform the subscription and its transform
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

extension HACacheSubscribeInfo.Response: Equatable where OutgoingType: Equatable {}
