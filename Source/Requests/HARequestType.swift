/// The command to issue
public struct HARequestType: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    // MARK: - Internal

    public static var auth: Self = "auth" // no reason external consumers should use this

    // MARK: - Requests

    public static var callService: Self = "call_service"
    public static var currentUser: Self = "auth/current_user"
    public static var getStates: Self = "get_states"
    public static var getConfig: Self = "get_config"
    public static var getServices: Self = "get_services"

    // MARK: - Subscription Handling

    public static var subscribeEvents: Self = "subscribe_events"
    public static var unsubscribeEvents: Self = "unsubscribe_events"

    // MARK: - Subscriptions

    public static var renderTemplate: Self = "render_template"
}
