import Foundation

/// An entity in Home Assistant
public struct HAEntity: HADataDecodable {
    /// The entity id, e.g. `sun.sun` or `light.office`
    public var entityId: String
    /// The domain of the entity id, e.g. `light` in `light.office`
    public var domain: String
    /// The current state of the entity
    public var state: String
    /// When the entity was last changed
    public var lastChanged: Date
    /// When the entity was last updated
    public var lastUpdated: Date
    /// Attributes of the entity
    ///
    /// - TODO: as strongly typed
    public var attributes: [String: Any]
    /// Context of the entity's last update
    ///
    /// - TODO: as strongly typed
    public var context: [String: Any]

    /// Create an entity from a data response
    /// - Parameter data: The data to create from
    /// - Throws: When the data is missing any required fields
    public init(data: HAData) throws {
        let entityId: String = try data.decode("entity_id")

        self.init(
            entityId: entityId,
            domain: try {
                guard let dot = entityId.firstIndex(of: ".") else {
                    throw HADataError.couldntTransform(key: "entity_id")
                }

                return String(entityId[..<dot])
            }(),
            state: try data.decode("state"),
            lastChanged: try data.decode("last_changed"),
            lastUpdated: try data.decode("last_updated"),
            attributes: try data.decode("attributes"),
            context: try data.decode("context")
        )
    }

    /// Create an entity from individual items
    /// - Parameters:
    ///   - entityId: The entity ID
    ///   - domain: The domain of the entity ID
    ///   - state: The state
    ///   - lastChanged: The date last changed
    ///   - lastUpdated: The date last updated
    ///   - attributes: The attributes of the entity
    ///   - context: The context of the entity
    public init(
        entityId: String,
        domain: String,
        state: String,
        lastChanged: Date,
        lastUpdated: Date,
        attributes: [String: Any],
        context: [String: Any]
    ) {
        precondition(entityId.starts(with: domain))
        self.entityId = entityId
        self.domain = domain
        self.state = state
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.attributes = attributes
        self.context = context
    }
}
