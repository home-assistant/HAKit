import Foundation

public extension HATypedSubscription {
    /// Render a template and subscribe to live changes of the template
    ///
    /// - Parameters:
    ///   - template: The template to render
    ///   - variables: The variables to provide to the template render on the server
    ///   - timeout: Optional timeout for how long the template can take to render
    /// - Returns: A typed subscriptions that can be sent via `HAConnection`
    static func renderTemplate(
        _ template: String,
        variables: [String: Any] = [:],
        timeout: Measurement<UnitDuration>? = nil
    ) -> HATypedSubscription<HAResponseRenderTemplate> {
        var data: [String: Any] = [:]
        data["template"] = template
        data["variables"] = variables

        if let timeout = timeout {
            data["timeout"] = timeout.converted(to: .seconds).value
        }

        return .init(request: .init(type: .renderTemplate, data: data))
    }
}

/// Template rendered event
public struct HAResponseRenderTemplate: HADataDecodable {
    /// The result of the template render
    ///
    /// Note that this can be any type: number, string, boolean, dictionary, array, etc.
    /// Templates are rendered into native JSON types and we cannot make a client-side type-safe value here.
    public var result: Any
    /// What listeners apply to the requested template
    public var listeners: Listeners

    /// The listeners for the template render
    ///
    /// For example, listening to 'all' entities (via accessing all states) or to certain entities.
    /// This is potentially useful to display when configuring a template as it will provide context clues about
    /// the performance of a particular template.
    public struct Listeners: HADataDecodable {
        /// All states are listened to
        public var all: Bool
        /// The current time is listened to
        public var time: Bool
        /// Entities that are listened to
        public var entities: [String]
        /// Domains (e.g. `light`) that are listened to
        public var domains: [String]

        /// Create with data
        /// - Parameter data: The data from the server
        /// - Throws: If any required keys are missing
        public init(data: HAData) throws {
            self.init(
                all: data.decode("all", fallback: false),
                time: data.decode("time", fallback: false),
                entities: data.decode("entities", fallback: []),
                domains: data.decode("domains", fallback: [])
            )
        }

        /// Create with information
        /// - Parameters:
        ///   - all: Whether all states are listened to
        ///   - time: Whether the current time is listened to
        ///   - entities: Entities that are listened to
        ///   - domains: Domains that are listened to
        public init(
            all: Bool,
            time: Bool,
            entities: [String],
            domains: [String]
        ) {
            self.all = all
            self.time = time
            self.entities = entities
            self.domains = domains
        }
    }

    /// Create with data
    /// - Parameter data: The data from the server
    /// - Throws: If any required keys are missing
    public init(data: HAData) throws {
        self.init(
            result: try data.decode("result"),
            listeners: try data.decode("listeners")
        )
    }

    /// Create with information
    /// - Parameters:
    ///   - result: The result of the render template
    ///   - listeners: The listeners of the render template
    public init(result: Any, listeners: Listeners) {
        self.result = result
        self.listeners = listeners
    }
}
