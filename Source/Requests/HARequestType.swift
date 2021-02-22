/// The command to issue
public struct HARequestType: RawRepresentable, Hashable {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Requests

    public static var callService: Self = .init(rawValue: "call_service")
    public static var currentUser: Self = .init(rawValue: "auth/current_user")
    public static var getStates: Self = .init(rawValue: "get_states")
    public static var getConfig: Self = .init(rawValue: "get_config")
    public static var getServices: Self = .init(rawValue: "get_services")

    // MARK: - Subscription Handling

    public static var subscribeEvents: Self = .init(rawValue: "subscribe_events")
    public static var unsubscribeEvents: Self = .init(rawValue: "unsubscribe_events")

    // MARK: - Subscriptions

    public static var renderTemplate: Self = .init(rawValue: "render_template")
}
