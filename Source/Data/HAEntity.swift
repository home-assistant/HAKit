import Foundation

/// An entity in Home Assistant
public struct HAEntity {
    /// The entity id, e.g. `sun.sun` or `light.office`
    var entityId: String
    /// The current state of the entity
    var state: String
    /// When the entity was last changed
    var lastChanged: Date
    /// When the entity was last updated
    var lastUpdated: Date
    /// Attributes of the entity
    ///
    /// - TODO: as strongly typed
    var attributes: [String: Any]
    /// Context of the entity's last update
    ///
    /// - TODO: as strongly typed
    var context: [String: Any]

    public init(data: HAData) throws {
        self.init(
            entityId: try data.decode("entity_id"),
            state: try data.decode("state"),
            lastChanged: try data.decode("last_changed"),
            lastUpdated: try data.decode("last_updated"),
            attributes: try data.decode("attributes"),
            context: try data.decode("context")
        )
    }

    public init(
        entityId: String,
        state: String,
        lastChanged: Date,
        lastUpdated: Date,
        attributes: [String: Any],
        context: [String: Any]
    ) {
        self.entityId = entityId
        self.state = state
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.attributes = attributes
        self.context = context
    }
}
