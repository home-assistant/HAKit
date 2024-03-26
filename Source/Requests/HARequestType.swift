import Foundation

/// The command to issue
public enum HARequestType: Hashable, Comparable, ExpressibleByStringLiteral {
    /// Sent over WebSocket, the command of the request
    case webSocket(String)
    /// Sent over REST, the HTTP method to use and the post-`api/` path
    case rest(HAHTTPMethod, String)
    /// Sent over WebSocket, the stt binary handler id
    case sttData(HASttHandlerId)

    /// Create a WebSocket request type by string literal
    /// - Parameter value: The name of the WebSocket command
    public init(stringLiteral value: StringLiteralType) {
        self = .webSocket(value)
    }

    /// The command of the request, agnostic of protocol type
    public var command: String {
        switch self {
        case let .webSocket(command), let .rest(_, command):
            return command
        case .sttData:
            return ""
        }
    }

    /// The request is issued outside of the lifecycle of a connection
    public var isPerpetual: Bool {
        switch self {
        case .webSocket, .sttData: return false
        case .rest: return true
        }
    }

    /// Sort the request type by command name
    /// - Parameters:
    ///   - lhs: The first type to compare
    ///   - rhs: The second value to compare
    /// - Returns: Whether the first type preceeds the second
    public static func < (lhs: HARequestType, rhs: HARequestType) -> Bool {
        switch (lhs, rhs) {
        case (.webSocket, .rest): return true
        case (.rest, .webSocket): return false
        case let (.webSocket(lhsCommand), .webSocket(rhsCommand)),
             let (.rest(_, lhsCommand), .rest(_, rhsCommand)):
            return lhsCommand < rhsCommand
        case (.sttData, _), (_, .sttData):
            return false
        }
    }

    // MARK: - Requests

    /// `call_service`
    public static var callService: Self = "call_service"
    /// `auth/current_user`
    public static var currentUser: Self = "auth/current_user"
    /// `get_states`
    public static var getStates: Self = "get_states"
    /// `get_config`
    public static var getConfig: Self = "get_config"
    /// `get_services`
    public static var getServices: Self = "get_services"

    // MARK: - Subscription Handling

    /// `subscribe_events`
    public static var subscribeEvents: Self = "subscribe_events"
    /// `unsubscribe_events`
    public static var unsubscribeEvents: Self = "unsubscribe_events"
    /// `subscribe_entities`
    public static var subscribeEntities: Self = "subscribe_entities"

    // MARK: - Subscriptions

    /// `render_template`
    public static var renderTemplate: Self = "render_template"

    // MARK: - Internal

    /// `ping`
    /// This will always get a success response, when a response is received.
    public static var ping: Self = "ping"

    /// `auth`
    /// This is likely not useful for external consumers as this is handled automatically on connection.
    public static var auth: Self = "auth"
}
