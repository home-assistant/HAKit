import Foundation

/// Delegate of the connection
public protocol HAConnectionDelegate: AnyObject {
    /// The connection state has changed
    /// - Parameters:
    ///   - connection: The connection invoking this function
    ///   - state: The new state of the connection being transitioned to
    func connection(_ connection: HAConnectionProtocol, transitionedTo state: HAConnectionState)
}

/// State of the connection
public enum HAConnectionState {
    /// Reason for disconnection state
    public enum DisconnectReason {
        case initial
        case error(HAError)
        case waitingToReconnect(atLatest: Date, retryCount: Int)
    }

    /// Not connected
    /// - SeeAlso: `DisconnectReason`
    case disconnected(reason: DisconnectReason)
    /// Connection is actively being attempted
    case connecting
    /// The connection has been made and can process commands
    case ready(version: String)
}

/// Namespace for creating a new connection
public enum HAConnection {
    /// The type which represents an API connection
    public static var API: HAConnectionProtocol.Type = { HAConnectionImpl.self }()
    /// Create a new connection
    /// - Parameter configuration: The configuration for the connection
    /// - Returns: The connection itself
    public static func api(configuration: HAConnectionConfiguration) -> HAConnectionProtocol {
        // swiftformat:disable:next redundantInit
        Self.API.init(configuration: configuration)
    }
}

/// The interface for the API itself
public protocol HAConnectionProtocol: AnyObject {
    /// Handler invoked when a request completes
    typealias RequestCompletion = (Result<HAData, HAError>) -> Void
    /// Handler invoked when the initial request to start a subscription completes
    typealias SubscriptionInitiatedHandler = (Result<HAData, HAError>) -> Void
    /// Handler invoked when a subscription receives a new event
    typealias SubscriptionHandler = (HACancellable, HAData) -> Void

    /// The delegate of the connection
    var delegate: HAConnectionDelegate? { get set }

    /// Create a new connection
    ///
    /// - SeeAlso: `HAConnection` for the public interface to create connections
    /// - Parameter configuration: The configuration to create
    init(configuration: HAConnectionConfiguration)
    /// The current configuration for the connection
    var configuration: HAConnectionConfiguration { get set }

    /// The current state of the connection
    var state: HAConnectionState { get }

    /// The queue to invoke all handlers on
    /// This defaults to `DispatchQueue.main`
    var callbackQueue: DispatchQueue { get set }

    /// Attempt to connect to the server
    /// This will attempt immediately and then make retry attempts based on timing and/or reachability and/or application state
    func connect()
    /// Disconnect from the server or end reconnection attempts
    func disconnect()

    /// Send a request
    ///
    /// If the connection is currently disconnected, or this request fails to be responded to, this will be reissued in the future until it individually fails or is cancelled.
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
    /// If the connection is currently disconnected, or this request fails to be responded to, this will be reissued in the future until it individually fails or is cancelled.
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

/// Overall error wrapper for the library
public enum HAError: Error {
    /// An error occurred in parsing or other internal handling
    case `internal`(debugDescription: String)
    /// An error response from the server indicating a request problem
    case external(ExternalError)

    /// Description of a server-delivered error
    public struct ExternalError {
        /// The code provided with the error
        public var code: Int
        /// The message provided with the error
        public var message: String

        init(_ errorValue: Any?) {
            if let error = errorValue as? [String: Any],
               let code = error["code"] as? Int,
               let message = error["message"] as? String {
                self.code = code
                self.message = message
            } else {
                self.code = -1
                self.message = "unable to parse error response"
            }
        }
    }
}
