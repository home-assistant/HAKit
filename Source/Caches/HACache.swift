import Foundation

/// Cache
///
/// This class functions as a shared container of queries which can be live-updated from subscriptions.
/// For example, you might combine `HARequestType.getStates` with `HAEventType.stateChanged` to get all states and be
/// alerted for changes.
///
/// All methods on this class are thread-safe.
///
/// - Important: You, or another object, must keep a strong reference to this cache or a HACancellable returned to you;
///              the cache does not retain itself directly. This includes `map` values.
///
/// - Note: Use `shouldResetWithoutSubscribers` to control whether the subscription is disconnected when not in use.
/// - Note: Use `map(_:)` to make quasi-streamed changes to the cache contents.
public class HACache<ValueType> {
    /// The current value, if available, or the most recent value from a previous connection.
    /// A value would not be available when the initial request hasn't been responded to yet.
    public var current: ValueType? {
        state.read(\.current)
    }

    /// Whether the cache will unsubscribe from its subscription and reset its current value without any subscribers
    /// - Note: This is unrelated to whether the cache instance is kept in memory itself.
    public var shouldResetWithoutSubscribers: Bool {
        get { state.read(\.shouldResetWithoutSubscribers) }
        set { state.mutate { $0.shouldResetWithoutSubscribers = newValue } }
    }

    /// The callback queue to perform subscription handlers on. Defaults to the connection's callback queue.
    public var callbackQueue: DispatchQueue

    /// Subscribe to changes of this cache
    /// - Parameter handler: The handler to invoke when changes occur
    /// - Returns: A token to cancel the subscription; either this token _or_ the HACache instance must be retained.
    public func subscribe(_ handler: @escaping (HACancellable, ValueType) -> Void) -> HACancellable {
        let info = SubscriptionInfo(handler: handler)
        let cancellable = self.cancellable(for: info)

        state.mutate { state in
            state.subscribers.insert(info)

            // we know that if any state changes happen _after_ this, it'll be notified in another block
            if let current = state.current {
                callbackQueue.async {
                    info.handler(cancellable, current)
                }
            }
        }

        // if we are waiting on subscribers to start, we can do so now
        checkStateAndStart()

        return cancellable
    }

    /// Receive either the current value, or the next available value, from the cache
    ///
    /// - Parameter handler: The handler to invoke
    /// - Returns: A token to cancel the once lookup
    @discardableResult
    public func once(_ handler: @escaping (ValueType) -> Void) -> HACancellable {
        subscribe { [self] token, value in
            handler(value)
            token.cancel()

            // keep ourself around, in case the user did a `.map.once()`-style flow.
            // this differs in behavior from subscriptions, which do not retain outside of the cancellation token.
            withExtendedLifetime(self) {}
        }
    }

    /// Map the value to a new cache
    ///
    /// - Important: You, or another object, must strongly retain this newly-created cache or a cancellable for it.
    /// - Parameter transform: The transform to apply to this cache's value
    /// - Returns: The new cache
    public func map<NewType>(_ transform: @escaping (ValueType) -> NewType) -> HACache<NewType> {
        .init(from: self, transform: transform)
    }

    /// Information about a state change which needs transform
    public struct TransformInfo<IncomingType, OutgoingType> {
        /// The value coming into this state change
        /// For populate transforms, this is the request's response
        /// For subscribe transforms, this is the subscription's event value
        public var incoming: IncomingType

        /// The current value of the cache
        /// For populate transforms, this is nil if an initial request hasn't been sent yet and the cache not reset.
        /// For subscribe transforms, this is non-optional.
        public var current: OutgoingType
    }

    /// Information about the populate call in the cache
    ///
    /// This is issued in a few situations:
    ///   1. To initially populate the cache value for the first to-the-cache subscription
    ///   2. To update the value when reconnecting after having been disconnected
    ///   3. When a subscribe handler says that it needs to re-execute the populate to get a newer value
    public struct PopulateInfo<OutgoingType> {
        /// Type-erasing block to perform the populate and its transform
        internal let start: (HAConnection, @escaping ((OutgoingType?) -> OutgoingType) -> Void) -> HACancellable

        /// Create the information for populate
        /// - Parameters:
        ///   - request: The request to perform
        ///   - transform: The handler to convert the request's result into the cache's value type
        public init<IncomingType: HADataDecodable>(
            request: HATypedRequest<IncomingType>,
            transform: @escaping (TransformInfo<IncomingType, OutgoingType?>) -> OutgoingType
        ) {
            let nonRetryRequest: HATypedRequest<IncomingType> = {
                var updated = request
                updated.request.shouldRetry = false
                return updated
            }()
            self.start = { connection, perform in
                connection.send(nonRetryRequest, completion: { result in
                    guard let incoming = try? result.get() else { return }
                    perform { current in
                        transform(.init(incoming: incoming, current: current))
                    }
                })
            }
        }
    }

    /// Information about the subscriptions used to keep the cache up-to-date
    public struct SubscribeInfo<OutgoingType> {
        /// The response to a subscription event
        public enum Response {
            /// Issue the populate call again to get a newer value
            case reissuePopulate
            /// Replace the current cache value with this new one
            case replace(OutgoingType)
        }

        /// Type-erasing block to perform the subscription and its transform
        internal let start: (HAConnection, @escaping ((OutgoingType) -> Response) -> Void) -> HACancellable

        /// Create the information for subscription
        /// - Parameters:
        ///   - subscription: The subscription to perform after populate completes
        ///   - transform: The handler to convert the subscription's handler type into the cache's value
        public init<IncomingType: HADataDecodable>(
            subscription: HATypedSubscription<IncomingType>,
            transform: @escaping (TransformInfo<IncomingType, OutgoingType>) -> Response
        ) {
            let nonRetrySubscription: HATypedSubscription<IncomingType> = {
                var updated = subscription
                updated.request.shouldRetry = false
                return updated
            }()

            self.start = { connection, perform in
                connection.subscribe(to: nonRetrySubscription, handler: { _, incoming in
                    perform { current in
                        transform(.init(incoming: incoming, current: current))
                    }
                })
            }
        }
    }

    /// Create a cache
    ///
    /// This method is provided as a convenience to avoid having to wrap single-subscribe versions in an array.
    ///
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The info on how to fetch the initial/update data
    ///   - subscribe: The info (one or more) for what subscriptions to start for updates or triggers for populating
    public convenience init(
        connection: HAConnection,
        populate: PopulateInfo<ValueType>,
        subscribe: SubscribeInfo<ValueType>...
    ) {
        self.init(connection: connection, populate: populate, subscribe: subscribe)
    }

    /// Create a cache
    ///
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The info on how to fetch the initial/update data
    ///   - subscribe: The info (one or more) for what subscriptions to start for updates or triggers for populating
    public init(
        connection: HAConnection,
        populate: PopulateInfo<ValueType>,
        subscribe: [SubscribeInfo<ValueType>]
    ) {
        self.connection = connection
        self.callbackQueue = connection.callbackQueue

        self.start = { (connection: HAConnection, cache: HACache<ValueType>) -> HACancellable? in
            guard case .ready = connection.state else {
                return nil
            }

            return Self.send(populate: populate, on: connection, cache: cache) {
                cache.state.mutate { state in
                    state.requestTokens = subscribe.map { info in
                        Self.subscribe(to: info, on: connection, populate: populate, cache: cache)
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkStateAndStart),
            name: HAConnectionState.didTransitionToStateNotification,
            object: connection
        )
    }

    /// Do the underlying populate send
    /// - Parameters:
    ///   - populate: The populate to start
    ///   - connection: The connection to send on
    ///   - cache: The cache whose state should be updated
    ///   - completion: The completion to invoke after updating the cache
    /// - Returns: The cancellable token for the populate request
    private static func send<ValueType>(
        populate: PopulateInfo<ValueType>,
        on connection: HAConnection,
        cache: HACache<ValueType>,
        completion: @escaping () -> Void = {}
    ) -> HACancellable {
        populate.start(connection, { handler in
            let value: ValueType = cache.state.mutate { state in
                let value = handler(state.current)
                state.current = value
                return value
            }
            cache.notifyObservers(for: value)
            completion()
        })
    }

    /// Do the underlying subscribe
    /// - Parameters:
    ///   - subscription: The subscription info
    ///   - connection: The connection to subscribe on
    ///   - populate: The populate request, for re-issuing when needed
    ///   - cache: The cache whose state should be updated
    /// - Returns: The cancellable token for the subscription
    private static func subscribe<ValueType>(
        to subscription: SubscribeInfo<ValueType>,
        on connection: HAConnection,
        populate: PopulateInfo<ValueType>,
        cache: HACache<ValueType>
    ) -> HACancellable {
        subscription.start(connection, { [weak cache, weak connection] handler in
            guard let cache = cache, let connection = connection else { return }
            let value: ValueType? = cache.state.mutate { state in
                switch handler(state.current!) {
                case .reissuePopulate:
                    state.requestTokens.append(send(populate: populate, on: connection, cache: cache))
                    return nil
                case let .replace(value):
                    state.current = value
                    return value
                }
            }
            cache.notifyObservers(for: value)
        })
    }

    /// Create a cache by mapping an existing cache's value
    /// - Parameters:
    ///   - incomingCache: The cache to map values from; this is kept as a strong reference
    ///   - transform: The transform to apply to the values from the cache
    public init<IncomingType>(
        from incomingCache: HACache<IncomingType>,
        transform: @escaping (IncomingType) -> ValueType
    ) {
        self.connection = incomingCache.connection
        self.callbackQueue = incomingCache.callbackQueue
        self.start = { _, cache in
            // unfortunately, using this value directly crashes the swift compiler, so we call into it with this
            let cacheValue: HACache<ValueType> = cache
            return incomingCache.subscribe { [weak cacheValue] _, value in
                let value: ValueType? = cacheValue?.state.mutate { state in
                    let next = transform(value)
                    state.current = next
                    return next
                }
                cache.notifyObservers(for: value)
            }
        }
    }

    /// Create a cache with a constant value
    ///
    /// This is largely intended for tests or other situations where you want a cache you can control more strongly.
    ///
    /// - Parameter constantValue: The value to keep for state
    public init(constantValue: ValueType) {
        self.connection = nil
        self.callbackQueue = .main
        self.start = { _, cache in
            cache.state.mutate { state in
                state.current = constantValue
            }
            return nil
        }
    }

    deinit {
        state.read { state in
            if !state.subscribers.isEmpty {
                HAGlobal.log("HACache deallocating with \(state.subscribers.count) subscribers")
            }

            state.requestTokens.forEach { $0.cancel() }
        }
    }

    /// State of the cache
    private struct State {
        /// The current value of the cache, if one has been retrieved
        var current: ValueType?

        /// Current subscribers of the cache
        /// - Important: This will consult `shouldResetWithoutSubscribers` to decide if it should reset.
        var subscribers: Set<SubscriptionInfo> = Set([]) {
            didSet {
                resetIfNecessary()
            }
        }

        /// When true, the state of the cache will be reset if subscribers becomes empty
        var shouldResetWithoutSubscribers: Bool = false

        /// Contains populate, subscribe, and reissued-populate tokens
        var requestTokens: [HACancellable] = []

        /// Resets the state if there are no subscribers and it is set to do so
        /// - SeeAlso: `shouldResetWithoutSubscribers`
        mutating func resetIfNecessary() {
            guard shouldResetWithoutSubscribers, subscribers.isEmpty else {
                return
            }

            requestTokens.forEach { $0.cancel() }
            requestTokens.removeAll()
            current = nil
        }
    }

    /// The current state
    private var state = HAProtected<State>(value: .init())

    /// A subscriber
    private class SubscriptionInfo: Hashable {
        /// Used internally to decide which subscription is being cancelled
        var id: UUID
        /// The handler to invoke when changes occur
        var handler: (HACancellable, ValueType) -> Void

        /// Create subscription info
        /// - Parameter handler: The handler to invoke
        init(handler: @escaping (HACancellable, ValueType) -> Void) {
            let id = UUID()
            self.id = id
            self.handler = handler
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SubscriptionInfo, rhs: SubscriptionInfo) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// The connection to use and watch
    private weak var connection: HAConnection?
    /// Block to begin the prepare -> subscribe lifecycle
    /// This is a block to erase all the intermediate types for prepare/subscribe
    private let start: (HAConnection, HACache<ValueType>) -> HACancellable?

    /// Create a cancellable which removes this subscription
    /// - Parameter info: The subscription info that would be removed
    /// - Returns: A cancellable for the subscription info, which strongly retains this cache
    private func cancellable(for info: SubscriptionInfo) -> HACancellable {
        HACancellableImpl(handler: { [self] in
            state.mutate { state in
                state.subscribers.remove(info)
            }

            // just really emphasizing that we are strongly retaining self here on purpose
            withExtendedLifetime(self) {}
        })
    }

    /// Start the prepare -> subscribe lifecycle, if there are subscribers
    @objc private func checkStateAndStart() {
        guard let connection = connection else {
            HAGlobal.log("not subscribing to connection as the connection no longer exists")
            return
        }

        state.mutate { [self] state in
            guard !state.subscribers.isEmpty else {
                // No subscribers, do not connect.
                return
            }
            let token = start(connection, self)
            if let token = token {
                state.requestTokens.append(token)
            }
        }
    }

    /// Notify observers of a new value
    /// - Parameter value: The value to notify about
    /// - Note: This will fire on the connection's callback queue.
    private func notifyObservers(for value: ValueType?) {
        guard let value = value else { return }

        callbackQueue.async { [self] in
            for subscriber in state.read(\.subscribers) {
                subscriber.handler(cancellable(for: subscriber), value)
            }
        }
    }
}
