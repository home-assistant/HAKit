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

        self.init(
            request: subscription.request,
            anyTransform: { possibleValue in
                guard let value = possibleValue as? HACacheTransformInfo<IncomingType, OutgoingType> else {
                    throw TransformError.incorrectType(
                        have: String(describing: possibleValue),
                        expected: String(describing: IncomingType.self)
                    )
                }

                return transform(value)
            }, start: { connection, perform in
                var operationType: HACacheSubscriptionPhase = .initial
                return connection.subscribe(to: nonRetrySubscription, handler: { _, incoming in
                    perform { current in
                        let transform = transform(.init(
                            incoming: incoming,
                            current: current,
                            subscriptionPhase: operationType
                        ))
                        operationType = .iteration
                        return transform
                    }
                })
            }
        )
    }

    /// The untyped request that underlies the subscription that created this info
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
    ///   - subscriptionPhase: The phase in which the subscription is, initial iteration or subsequent
    /// - Throws: If the type of incoming does not match the original IncomingType
    /// - Returns: The response from the transform block
    public func transform<IncomingType>(
        incoming: IncomingType,
        current: OutgoingType,
        subscriptionPhase: HACacheSubscriptionPhase
    ) throws -> Response {
        try anyTransform(HACacheTransformInfo<IncomingType, OutgoingType>(
            incoming: incoming,
            current: current,
            subscriptionPhase: subscriptionPhase
        ))
    }

    /// The start handler
    typealias StartHandler = (HAConnection, @escaping ((OutgoingType) -> Response) -> Void) -> HACancellable

    /// Type-erasing block to perform the subscription and its transform
    internal let start: StartHandler

    /// Helper to allow writing tests around the struct value
    internal var anyTransform: (Any) throws -> Response

    /// Create with a start block
    ///
    /// Only really useful in unit tests to avoid setup.
    ///
    /// - Parameters:
    ///   - request: The request that is tied to the subscription
    ///   - anyTransform: The transform to provide for testing this value
    ///   - start: The start block
    internal init(request: HARequest, anyTransform: @escaping (Any) throws -> Response, start: @escaping StartHandler) {
        self.request = request
        self.start = start
        self.anyTransform = anyTransform
    }
}

extension HACacheSubscribeInfo.Response: Equatable where OutgoingType: Equatable {}
