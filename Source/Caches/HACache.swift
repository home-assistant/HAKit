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

    /// Create a cache that requires no transformations on the underlying data type
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The request to fetch the data
    ///   - subscribe: The request to subscribe to data changes
    public convenience init(
        connection: HAConnection,
        populate: HATypedRequest<ValueType>,
        subscribe: HATypedSubscription<ValueType>
    ) where ValueType: HADataDecodable {
        self.init(
            connection: connection,
            populate: populate,
            populateTransform: \.incoming,
            subscribe: subscribe,
            subscribeTransform: \.incoming
        )
    }

    /// Create a cache that requires no transformations of the request but requires of the subscription.
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The request to fetch the data
    ///   - subscribe: The request to subscribe to data changes
    ///   - subscribeTransform: The transform to apply to the subscription data
    public convenience init<SubscribeType>(
        connection: HAConnection,
        populate: HATypedRequest<ValueType>,
        subscribe: HATypedSubscription<SubscribeType>,
        subscribeTransform: @escaping (TransformInfo<SubscribeType, ValueType>) -> ValueType
    ) where ValueType: HADataDecodable {
        self.init(
            connection: connection,
            populate: populate,
            populateTransform: \.incoming,
            subscribe: subscribe,
            subscribeTransform: subscribeTransform
        )
    }

    /// Create a cache that requires transformations of the request but not of the subscription.
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The request to fetch the data
    ///   - populateTransform: The transform to apply to the population request
    ///   - subscribe: The request to subscribe to data changes
    public convenience init<PopulateType>(
        connection: HAConnection,
        populate: HATypedRequest<PopulateType>,
        populateTransform: @escaping (TransformInfo<PopulateType, ValueType?>) -> ValueType,
        subscribe: HATypedSubscription<ValueType>
    ) where ValueType: HADataDecodable {
        self.init(
            connection: connection,
            populate: populate,
            populateTransform: populateTransform,
            subscribe: subscribe,
            subscribeTransform: \.incoming
        )
    }

    /// Create a cache that requires transformations for both the request and subscription
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - populate: The request to fetch the data
    ///   - populateTransform: The transform to apply to the population request
    ///   - subscribe: The request to subscribe to data changes
    ///   - subscribeTransform: The transform to apply to the subscription data
    public init<PopulateType, SubscribeType>(
        connection: HAConnection,
        populate: HATypedRequest<PopulateType>,
        populateTransform: @escaping (TransformInfo<PopulateType, ValueType?>) -> ValueType,
        subscribe: HATypedSubscription<SubscribeType>,
        subscribeTransform: @escaping (TransformInfo<SubscribeType, ValueType>) -> ValueType
    ) {
        self.connection = connection
        self.callbackQueue = connection.callbackQueue

        let nonRetryPopulate: HATypedRequest<PopulateType> = {
            var updated = populate
            updated.request.shouldRetry = false
            return updated
        }()
        let nonRetrySubscribe: HATypedSubscription<SubscribeType> = {
            var updated = subscribe
            updated.request.shouldRetry = false
            return updated
        }()

        self.start = { connection, cache in
            guard case .ready = connection.state else {
                return nil
            }

            return connection.send(nonRetryPopulate, completion: { result in
                guard let initialPopulateType = try? result.get() else { return }

                let initial: ValueType = cache.state.mutate(using: { state in
                    let initial = populateTransform(.init(incoming: initialPopulateType, current: state.current))
                    state.current = initial

                    state.requestToken = connection.subscribe(
                        to: nonRetrySubscribe,
                        handler: { [unowned cache] _, result in
                            let value: ValueType = cache.state.mutate { state in
                                let next = subscribeTransform(.init(
                                    incoming: result,
                                    current: state.current!
                                ))
                                state.current = next
                                return next
                            }
                            cache.notifyObservers(for: value)
                        }
                    )

                    return initial
                })

                cache.notifyObservers(for: initial)
            })
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkStateAndStart),
            name: HAConnectionState.didTransitionToStateNotification,
            object: connection
        )
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
            return incomingCache.subscribe { [unowned cacheValue] _, value in
                let value: ValueType = cacheValue.state.mutate { state in
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

            state.requestToken?.cancel()
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

        /// The current request token, either of the initial populate request or the subscription afterwards
        var requestToken: HACancellable? {
            didSet {
                oldValue?.cancel()
            }
        }

        /// Resets the state if there are no subscribers and it is set to do so
        /// - SeeAlso: `shouldResetWithoutSubscribers`
        mutating func resetIfNecessary() {
            guard shouldResetWithoutSubscribers, subscribers.isEmpty else {
                return
            }

            requestToken = nil
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
    /// - Returns: A cancelalble for the subscription info, which strongly retains this cache
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
                state.requestToken = nil
                return
            }
            state.requestToken = start(connection, self)
        }
    }

    /// Notify observers of a new value
    /// - Parameter value: The value to notify about
    /// - Note: This will fire on the connection's callback queue.
    private func notifyObservers(for value: ValueType) {
        callbackQueue.async { [self] in
            for subscriber in state.read(\.subscribers) {
                subscriber.handler(cancellable(for: subscriber), value)
            }
        }
    }
}
