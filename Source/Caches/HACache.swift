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
        populate: HACachePopulateInfo<ValueType>,
        subscribe: HACacheSubscribeInfo<ValueType>...
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
        populate: HACachePopulateInfo<ValueType>,
        subscribe: [HACacheSubscribeInfo<ValueType>]
    ) {
        self.connection = connection
        self.populateInfo = populate
        self.subscribeInfo = subscribe

        self.start = { connection, cache in
            Self.startPopulate(for: populate, on: connection, cache: cache) { cacheResult in
                switch cacheResult {
                case let .success(cache):
                    cache.state.mutate { state in
                        let tokens = subscribe.map { info in
                            Self.startSubscribe(to: info, on: connection, populate: populate, cache: cache)
                        }
                        state.setRequestTokens(tokens, cancellingPrevious: false)
                    }
                case .failure:
                    // we're stuck, but we'll retry when this connection drops and reconnects.
                    break
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

    /// Create a cache that relies on subscription updates without initial population.
    ///
    /// - Parameters:
    ///   - connection: The connection to use and watch
    ///   - subscribe: The info (one or more) for what subscriptions to start for updates or triggers for populating
    public init(
        connection: HAConnection,
        subscribe: HACacheSubscribeInfo<ValueType>
    ) {
        self.connection = connection
        self.populateInfo = nil
        self.subscribeInfo = [subscribe]

        self.start = { connection, cache in
            Self.startSubscribe(to: subscribe, on: connection, populate: nil, cache: cache)
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
        self.populateInfo = nil
        self.subscribeInfo = nil
        self.start = { _, someCache in
            // unfortunately, using this value directly crashes the swift compiler, so we call into it with this
            let cache: HACache<ValueType> = someCache
            return incomingCache.subscribe { [weak cache] _, value in
                cache?.state.mutate { state in
                    let next = transform(value)
                    state.current = next
                    cache?.notify(subscribers: state.subscribers, for: next)
                }
            }
        }
        state.mutate { state in
            state.current = incomingCache.value.map(transform)
        }
    }

    /// Create a cache with a constant value
    ///
    /// This is largely intended for tests or other situations where you want a cache you can control more strongly.
    ///
    /// - Parameter constantValue: The value to keep for state
    public init(constantValue: ValueType) {
        self.connection = nil
        self.start = { _, _ in
            fatalError("connection is never non-nil; this cannot be called")
        }
        self.populateInfo = nil
        self.subscribeInfo = nil
        state.mutate { state in
            state.current = constantValue
        }
    }

    deinit {
        state.read { state in
            if !state.subscribers.isEmpty {
                HAGlobal.log(.error, "HACache deallocating with \(state.subscribers.count) subscribers")
            }

            state.requestTokens.forEach { $0.cancel() }
        }
    }

    /// The current value, if available, or the most recent value from a previous connection.
    /// A value would not be available when the initial request hasn't been responded to yet.
    public var value: ValueType? {
        state.read(\.current)
    }

    /// Whether the cache will unsubscribe from its subscription and reset its current value without any subscribers
    /// - Note: This is unrelated to whether the cache instance is kept in memory itself.
    public var shouldResetWithoutSubscribers: Bool {
        get { state.read(\.shouldResetWithoutSubscribers) }
        set { state.mutate { $0.shouldResetWithoutSubscribers = newValue } }
    }

    /// Subscribe to changes of this cache
    ///
    /// No guarantees are made about the order added subscriptions will be invoked in.
    ///
    /// - Parameter handler: The handler to invoke when changes occur
    /// - Returns: A token to cancel the subscription; either this token _or_ the HACache instance must be retained.
    public func subscribe(_ handler: @escaping (HACancellable, ValueType) -> Void) -> HACancellable {
        let info = SubscriptionInfo(handler: handler)
        let cancellable = self.cancellable(for: info)

        let shouldRefresh: Bool = state.mutate { state in
            let wasEmpty = state.subscribers.isEmpty
            let shouldRefresh = state.current == nil || state.shouldResetWithoutSubscribers
            state.subscribers.insert(info)

            // we know that if any state changes happen _after_ this, it'll be notified in another block
            if let current = state.current {
                callbackQueue.async {
                    info.handler(cancellable, current)
                }
            }

            return wasEmpty && shouldRefresh
        }

        // if we are waiting on subscribers to start, we can do so now
        if shouldRefresh {
            checkStateAndStart()
        }

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

    /// State of the cache
    private struct State {
        /// The current value of the cache, if one has been retrieved
        var current: ValueType?

        /// Whether we're currently sending, or waiting for a response to, our populate.
        var isWaitingForPopulate = false

        /// Current subscribers of the cache
        /// - Important: This will consult `shouldResetWithoutSubscribers` to decide if it should reset.
        var subscribers: Set<SubscriptionInfo> = Set([]) {
            didSet {
                resetIfNecessary()
            }
        }

        /// When true, the state of the cache will be reset if subscribers becomes empty
        var shouldResetWithoutSubscribers: Bool = false {
            didSet {
                resetIfNecessary()
            }
        }

        /// Contains populate, subscribe, and reissued-populate tokens
        private(set) var requestTokens: [HACancellable] = []

        /// Add request tokens, optionally cancelling
        /// - Parameters:
        ///   - tokens: The tokens to set to
        ///   - cancellingPrevious: Whether to cancel previous requests
        mutating func setRequestTokens(_ tokens: [HACancellable], cancellingPrevious: Bool) {
            if cancellingPrevious {
                requestTokens.forEach { $0.cancel() }
            }
            requestTokens = tokens
        }

        /// Add request tokens, never cancelling previous
        /// - Parameter token: The token to append
        mutating func appendRequestToken(_ token: HACancellable) {
            requestTokens.append(token)
        }

        /// Resets the state if there are no subscribers and it is set to do so
        /// - SeeAlso: `shouldResetWithoutSubscribers`
        mutating func resetIfNecessary() {
            guard shouldResetWithoutSubscribers, subscribers.isEmpty else {
                return
            }

            setRequestTokens([], cancellingPrevious: true)
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
    internal weak var connection: HAConnection?
    /// Block to begin the prepare -> subscribe lifecycle
    /// This is a block to erase all the intermediate types for prepare/subscribe
    private let start: (HAConnection, HACache<ValueType>) -> HACancellable
    /// The callback queue to perform subscription handlers on.
    private var callbackQueue: DispatchQueue {
        connection?.callbackQueue ?? .main
    }

    /// If this cache was created with populate info, this contains that info
    /// This is largely intended for tests and is not used internally.
    public let populateInfo: HACachePopulateInfo<ValueType>?
    /// If this cache was created with subscribe info, this contains that info
    /// This is largely intended for tests and is not used internally.
    public let subscribeInfo: [HACacheSubscribeInfo<ValueType>]?

    /// Do the underlying populate send
    /// - Parameters:
    ///   - populate: The populate to start
    ///   - connection: The connection to send on
    ///   - cache: The cache whose state should be updated
    ///   - completion: The completion to invoke after updating the cache
    /// - Returns: The cancellable token for the populate request
    private static func startPopulate<ValueType>(
        for populate: HACachePopulateInfo<ValueType>,
        on connection: HAConnection,
        cache: HACache<ValueType>,
        completion: @escaping (Result<HACache<ValueType>, Error>) -> Void = { _ in }
    ) -> HACancellable {
        populate.start(connection, { [weak cache] handler in
            guard let cache = cache else { return }
            let result: Result<HACache<ValueType>, Error> = cache.state.mutate { state in
                state.isWaitingForPopulate = false

                do {
                    let value = try handler(state.current)
                    state.current = value
                    cache.notify(subscribers: state.subscribers, for: value)
                    return .success(cache)
                } catch {
                    HAGlobal.log(.error, "populate failed: \(error)")
                    return .failure(error)
                }
            }
            completion(result)
        })
    }

    /// Do the underlying subscribe
    /// - Parameters:
    ///   - subscription: The subscription info
    ///   - connection: The connection to subscribe on
    ///   - populate: The populate request, for re-issuing when needed
    ///   - cache: The cache whose state should be updated
    /// - Returns: The cancellable token for the subscription
    private static func startSubscribe<ValueType>(
        to subscription: HACacheSubscribeInfo<ValueType>,
        on connection: HAConnection,
        populate: HACachePopulateInfo<ValueType>?,
        cache: HACache<ValueType>
    ) -> HACancellable {
        subscription.start(connection, { [weak cache, weak connection] handler in
            guard let cache, let connection else { return }
            cache.state.mutate { state in
                switch handler(state.current) {
                case .ignore: break
                case .reissuePopulate:
                    if let populate {
                        let populateToken = startPopulate(for: populate, on: connection, cache: cache)
                        state.appendRequestToken(populateToken)
                    }
                case let .replace(value):
                    state.current = value
                    cache.notify(subscribers: state.subscribers, for: value)
                }
            }
        })
    }

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
            HAGlobal.log(.error, "not subscribing to connection as the connection no longer exists")
            return
        }

        state.mutate { state in
            guard !state.subscribers.isEmpty else {
                // No subscribers, do not connect.
                return
            }

            // In case initial populate is not needed, populate will be nil
            guard !state.isWaitingForPopulate || populateInfo == nil else {
                // Currently waiting on a populate, which will be retried by the connection for us.
                return
            }
            state.isWaitingForPopulate = true
            let token = start(connection, self)
            state.setRequestTokens([token], cancellingPrevious: true)
        }
    }

    /// Notify observers of a new value
    ///
    /// - Note: This will fire on the connection's callback queue.
    /// - Parameters:
    ///   - subscribers: The subscribers to call
    ///   - value: The value to notify about
    private func notify(
        subscribers: Set<SubscriptionInfo>,
        for value: ValueType
    ) {
        callbackQueue.async { [self] in
            for subscriber in subscribers {
                subscriber.handler(cancellable(for: subscriber), value)
            }
        }
    }
}
