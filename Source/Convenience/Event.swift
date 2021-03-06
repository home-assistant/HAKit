import Foundation

public extension HATypedSubscription {
    /// Subscribe to one or all events on the event bus
    ///
    /// - Parameter type: The event type to subscribe to. Pass `.all` to subscribe to all events.
    /// - Returns: A typed subscriptions that can be sent via `HAConnection`
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

/// The type of the event
public struct HAEventType: RawRepresentable, Hashable, ExpressibleByStringLiteral, ExpressibleByNilLiteral {
    /// The underlying string representing the event, or nil for all events
    public var rawValue: String?
    /// Create a type instance with a given string name
    /// - Parameter rawValue: The string name
    public init(rawValue: String?) {
        self.rawValue = rawValue
    }

    /// Create a type instance via a string literal
    /// - Parameter value: The string literal
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    /// Create a type instance via a nil literal, representing all events
    /// - Parameter nilLiteral: Unused
    public init(nilLiteral: ()) {
        self.init(rawValue: nil)
    }

    /// All events
    public static var all: Self = nil

    // rule of thumb: any event available in `core` is valid for this list

    /// `call_service`
    public static var callService: Self = "call_service"
    /// `component_loaded`
    public static var componentLoaded: Self = "component_loaded"
    /// `core_config_updated`
    public static var coreConfigUpdated: Self = "core_config_updated"
    /// `homeassistant_close`
    public static var homeassistantClose: Self = "homeassistant_close"
    /// `homeassistant_final_write`
    public static var homeassistantFinalWrite: Self = "homeassistant_final_write"
    /// `homeassistant_start`
    public static var homeassistantStart: Self = "homeassistant_start"
    /// `homeassistant_started`
    public static var homeassistantStarted: Self = "homeassistant_started"
    /// `homeassistant_stop`
    public static var homeassistantStop: Self = "homeassistant_stop"
    /// `logbook_entry`
    public static var logbookEntry: Self = "logbook_entry"
    /// `platform_discovered`
    public static var platformDiscovered: Self = "platform_discovered"
    /// `service_registered`
    public static var serviceRegistered: Self = "service_registered"
    /// `service_removed`
    public static var serviceRemoved: Self = "service_removed"
    /// `shopping_list_updated`
    public static var shoppingListUpdated: Self = "shopping_list_updated"
    /// `state_changed`
    public static var stateChanged: Self = "state_changed"
    /// `themes_updated`
    public static var themesUpdated: Self = "themes_updated"
    /// `timer_out_of_sync`
    public static var timerOutOfSync: Self = "timer_out_of_sync"
}

/// An event fired on the event bus
public struct HAResponseEvent: HADataDecodable {
    /// The type of event
    public var type: HAEventType
    /// When the event was fired
    public var timeFired: Date
    /// Data that came with the event
    public var data: [String: Any]
    /// The origin of the event
    public var origin: Origin
    /// The context of the event, e.g. who executed it
    public var context: Context

    /// The origin of the event
    public enum Origin: String {
        /// Local, aka added to the event bus via a component
        case local = "LOCAL"
        /// Remote, aka added to the event bus via an API call
        case remote = "REMOTE"
    }

    /// The context of the event
    public struct Context {
        /// The identifier for this event
        public var id: String
        /// The user id which triggered the event, if there was one
        public var userId: String?
        /// The identifier of the parent event for this event
        public var parentId: String?

        /// Create with data
        /// - Parameter data: The data from the server
        /// - Throws: If any required keys are missing
        public init(data: HAData) throws {
            self.init(
                id: try data.decode("id"),
                userId: data.decode("user_id", fallback: nil),
                parentId: data.decode("parent_id", fallback: nil)
            )
        }

        /// Create with information
        /// - Parameters:
        ///   - id: The id of the event
        ///   - userId: The user id of the event
        ///   - parentId: The parent id of the event
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

    /// Create with data
    /// - Parameter data: The data from the server
    /// - Throws: If any required keys are missing
    public init(data: HAData) throws {
        self.init(
            type: .init(rawValue: try data.decode("event_type")),
            timeFired: try data.decode("time_fired"),
            data: data.decode("data", fallback: [:]),
            origin: try data.decode("origin", transform: Origin.init(rawValue:)),
            context: try data.decode("context", transform: Context.init(data:))
        )
    }

    /// Create with information
    /// - Parameters:
    ///   - type: The type of the event
    ///   - timeFired: The time fired
    ///   - data: The data
    ///   - origin: The origin
    ///   - context: The context
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
