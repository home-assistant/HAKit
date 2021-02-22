import Foundation

public extension HATypedSubscription {
    /// Subscribe to one or all events on the event bus
    ///
    /// - Parameter type: The event type to subscribe to. Pass `.all` to subscribe to all events.
    /// - Returns: A typed subscriptions that can be sent via `HAConnectionProtocol`
    static func events(
        _ type: HAEventType
    ) -> HATypedSubscription<HAResponseEvent> {
        var data: [String: Any] = [:]

        if let rawType = type.rawValue {
            data["event_type"] = rawType
        }

        return .init(request: .init(type: .subscribeEvents, data: data))
    }
}

internal extension HATypedRequest {
    static func unsubscribe(
        _ identifier: HARequestIdentifier
    ) -> HATypedRequest<HAResponseVoid> {
        .init(request: .init(
            type: .unsubscribeEvents,
            data: ["subscription": identifier.rawValue],
            shouldRetry: false
        ))
    }
}

public struct HAEventType: RawRepresentable, Hashable {
    public var rawValue: String?
    public init(rawValue: String?) {
        self.rawValue = rawValue
    }

    public static var all: Self = .init(rawValue: nil)

    // rule of thumb: any event available in `core` is valid for this list
    public static var callService: Self = .init(rawValue: "call_service")
    public static var componentLoaded: Self = .init(rawValue: "component_loaded")
    public static var coreConfigUpdated: Self = .init(rawValue: "core_config_updated")
    public static var homeassistantClose: Self = .init(rawValue: "homeassistant_close")
    public static var homeassistantFinalWrite: Self = .init(rawValue: "homeassistant_final_write")
    public static var homeassistantStart: Self = .init(rawValue: "homeassistant_start")
    public static var homeassistantStarted: Self = .init(rawValue: "homeassistant_started")
    public static var homeassistantStop: Self = .init(rawValue: "homeassistant_stop")
    public static var logbookEntry: Self = .init(rawValue: "logbook_entry")
    public static var platformDiscovered: Self = .init(rawValue: "platform_discovered")
    public static var serviceRegistered: Self = .init(rawValue: "service_registered")
    public static var serviceRemoved: Self = .init(rawValue: "service_removed")
    public static var shoppingListUpdated: Self = .init(rawValue: "shopping_list_updated")
    public static var stateChanged: Self = .init(rawValue: "state_changed")
    public static var themesUpdated: Self = .init(rawValue: "themes_updated")
    public static var timerOutOfSync: Self = .init(rawValue: "timer_out_of_sync")
}

public struct HAResponseEvent: HADataDecodable {
    public var type: HAEventType
    public var timeFired: Date
    public var data: [String: Any]
    public var origin: Origin
    public var context: Context

    public enum Origin: String {
        case local = "LOCAL"
        case remote = "REMOTE"
    }

    public struct Context {
        public var id: String
        public var userId: String?
        public var parentId: String?

        public init(data: HAData) throws {
            self.init(
                id: try data.decode("id"),
                userId: data.decode("user_id", fallback: nil),
                parentId: data.decode("parent_id", fallback: nil)
            )
        }

        public init(
            id: String,
            userId: String?,
            parentId: String?
        ) {
            self.id = id
            self.userId = userId
            self.parentId = parentId
        }
    }

    public init(data: HAData) throws {
        self.type = .init(rawValue: try data.decode("event_type"))
        self.timeFired = try data.decode("time_fired")
        self.data = data.decode("data", fallback: [:])
        self.origin = try data.decode("origin", transform: Origin.init(rawValue:))
        self.context = try data.decode("context", transform: Context.init(data:))
    }

    public init(
        type: HAEventType,
        timeFired: Date,
        data: [String: Any],
        origin: Origin,
        context: Context
    ) {
        self.type = type
        self.timeFired = timeFired
        self.data = data
        self.origin = origin
        self.context = context
    }
}
