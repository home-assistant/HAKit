/// The command to issue
public struct HARequestType: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
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
