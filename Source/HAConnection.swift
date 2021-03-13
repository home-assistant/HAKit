import Foundation

/// Delegate of the connection
public protocol HAConnectionDelegate: AnyObject {
    /// The connection state has changed
    /// - Parameters:
    ///   - connection: The connection invoking this function
    ///   - state: The new state of the connection being transitioned to
    /// - SeeAlso: `HAConnectionState.didTransitionToStateNotification`
    func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState)
}

/// State of the connection
public enum HAConnectionState: Equatable {
    /// Notification fired when state transitions occur
    ///
    /// The object of the notification will be the connection.
    /// UserInfo will be nil.
    /// Notification fires on `NotificationCenter.default`.
    public static var didTransitionToStateNotification: Notification.Name { .init("HAConnectionDidTransitiontoState") }

    /// Reason for disconnection state
    public enum DisconnectReason: Equatable {
        public static func == (lhs: DisconnectReason, rhs: DisconnectReason) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected): return true
            case let (
                .waitingToReconnect(lhsError, lhsDate, lhsRetry),
                .waitingToReconnect(rhsError, rhsDate, rhsRetry)
            ):
                return lhsError as NSError? == rhsError as NSError?
                    && lhsDate == rhsDate
                    && lhsRetry == rhsRetry
            default: return false
            }
        }

        /// Disconnected and not going to automatically reconnect
        /// This can either be the initial state or after `disconnect()` is called
        case disconnected
        /// Waiting to reconnect, either by timer (with given Date) or network state changes
        case waitingToReconnect(lastError: Error?, atLatest: Date, retryCount: Int)
    }

    /// Not connected
    /// - SeeAlso: `DisconnectReason`
    case disconnected(reason: DisconnectReason)
    /// Connection is actively being attempted
    case connecting
    /// Connection established, getting/sending authentication details
    case authenticating
    /// The connection has been made and can process commands
    case ready(version: String)
}

/// The interface for the API itself
/// - SeeAlso: `HAKit` for how to create an instance
public protocol HAConnection: AnyObject {
    /// Handler invoked when a request completes
    typealias RequestCompletion = (Result<HAData, HAError>) -> Void
    /// Handler invoked when the initial request to start a subscription completes
    typealias SubscriptionInitiatedHandler = (Result<HAData, HAError>) -> Void
    /// Handler invoked when a subscription receives a new event
    typealias SubscriptionHandler = (HACancellable, HAData) -> Void

    /// The delegate of the connection
    var delegate: HAConnectionDelegate? { get set }

    /// The current configuration for the connection
    var configuration: HAConnectionConfiguration { get set }

    /// The current state of the connection
    var state: HAConnectionState { get }

    /// The queue to invoke all handlers on
    /// This defaults to `DispatchQueue.main`
    var callbackQueue: DispatchQueue { get set }

    /// Attempt to connect to the server
    /// This will attempt immediately and then make retry attempts based on timing and/or reachability and/or
    /// application state
    func connect()
    /// Disconnect from the server or end reconnection attempts
    func disconnect()

    /// Send a request
    ///
    /// If the connection is currently disconnected, or this request fails to be responded to, this will be reissued in
    /// the future until it individually fails or is cancelled.
    ///
    /// - Parameters:
    ///   - request: The request to send; invoked at most once
    ///   - completion: The handler to invoke on completion
    /// - Returns: A token which can be used to cancel the request
    @discardableResult
    func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable
    /// Send a request with a concrete response type
    ///
    /// If the connection is currently disconnected, or this request fails to be responded to, this will be reissued in
    /// the future until it individually fails or is cancelled.
    ///
    /// - SeeAlso: `HATypedRequest` extensions which create instances of it
    /// - Parameters:
    ///   - request: The request to send; invoked at most once
    ///   - completion: The handler to invoke on completion
    /// - Returns: A token which can be used to cancel the request
    @discardableResult
    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable

    /// Start a subscription to a request
    ///
    /// Subscriptions will automatically be restarted if the current connection to the server disconnects and then
    /// reconnects.
    ///
    /// - Parameters:
    ///   - request: The request to send to start the subscription
    ///   - handler: The handler to invoke when new events are received for the subscription; invoked many times
    /// - Returns: A token which can be used to cancel the subscription
    @discardableResult
    func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable
    /// Start a subscription and be notified about its start state
    ///
    /// Subscriptions will automatically be restarted if the current connection to the server disconnects and then
    /// reconnects. When each restart event occurs, the `initiated` handler will be invoked again.
    ///
    /// - Parameters:
    ///   - request: The request to send to start the subscription
    ///   - initiated: The handler to invoke when the subscription's initial request succeeds or fails; invoked once
    ///                per underlying WebSocket connection
    ///   - handler: The handler to invoke when new events are received for the subscription; invoked many times
    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable

    /// Start a subscription to a request with a concrete event type
    ///
    /// Subscriptions will automatically be restarted if the current connection to the server disconnects and then
    /// reconnects.
    ///
    /// - Parameters:
    ///   - request: The request to send to start the subscription
    ///   - handler: The handler to invoke when new events are received for the subscription; invoked many times
    /// - Returns: A token which can be used to cancel the subscription
    /// - SeeAlso: `HATypedSubscription` extensions which create instances of it
    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable
    /// Start a subscription to a request with a concrete event type
    ///
    /// Subscriptions will automatically be restarted if the current connection to the server disconnects and then
    /// reconnects. When each restart event occurs, the `initiated` handler will be invoked again.
    ///
    /// - Parameters:
    ///   - request: The request to send to start the subscription
    ///   - initiated: The handler to invoke when the subscription's initial request succeeds or fails; invoked once
    ///                per underlying WebSocket connection
    ///   - handler: The handler to invoke when new events are received for the subscription; invoked many times
    /// - Returns: A token which can be used to cancel the subscription
    /// - SeeAlso: `HATypedSubscription` extensions which create instances of it
    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable
}
