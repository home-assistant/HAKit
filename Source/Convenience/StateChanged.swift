public extension HATypedSubscription {
    /// Listen for state changes of all entities
    ///
    /// This is a convenient version of listening to the `.stateChanged` event, but with parsed response values.
    ///
    /// - Returns: A typed subscriptions that can be sent via `HAConnectionProtocol`
    static func stateChanged() -> HATypedSubscription<HAResponseEventStateChanged> {
        .init(request: .init(type: .subscribeEvents, data: [
            "event_type": HAEventType.stateChanged.rawValue!,
        ]))
    }
}

/// State changed event
public struct HAResponseEventStateChanged: HADataDecodable {
    /// The underlying event and the information it contains
    ///
    /// - TODO: should this be moved from composition to inheritence?
    public var event: HAResponseEvent
    /// The entity ID which is changing
    public var entityId: String
    /// The old state of the entity, if there was one
    public var oldState: HAEntity?
    /// The new state of the entity, if there is one
    public var newState: HAEntity?

    public init(data: HAData) throws {
        let event = try HAResponseEvent(data: data)
        let eventData = HAData.dictionary(event.data)

        self.init(
            event: event,
            entityId: try eventData.decode("entity_id"),
            oldState: try? eventData.decode("old_state", transform: HAEntity.init(data:)),
            newState: try? eventData.decode("new_state", transform: HAEntity.init(data:))
        )
    }

    public init(
        event: HAResponseEvent,
        entityId: String,
        oldState: HAEntity?,
        newState: HAEntity?
    ) {
        self.event = event
        self.entityId = entityId
        self.oldState = oldState
        self.newState = newState
    }
}
