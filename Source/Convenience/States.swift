public extension HATypedSubscription {
    /// Listen for state changes of all entities
    ///
    /// This is a convenient version of listening to the `.stateChanged` event, but with parsed response values.
    ///
    /// - Returns: A typed subscriptions that can be sent via `HAConnection`
    static func stateChanged() -> HATypedSubscription<HAResponseEventStateChanged> {
        .init(request: .init(type: .subscribeEvents, data: [
            "event_type": HAEventType.stateChanged.rawValue!,
        ]))
    }

    /// Listen for compressed state changes of all entities
    /// - Returns: A typed subscriptions that can be sent via `HAConnection`
    static func subscribeEntities() -> HATypedSubscription<CompressedStatesUpdates> {
        .init(request: .init(type: .subscribeEntities, data: [:]))
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

    /// Create with data
    /// - Parameter data: The data from the server
    /// - Throws: If any required keys are missing
    public init(data: HAData) throws {
        let event = try HAResponseEvent(data: data)
        let eventData = HAData.dictionary(event.data)

        self.init(
            event: event,
            entityId: try eventData.decode("entity_id"),
            oldState: try? eventData.decode("old_state"),
            newState: try? eventData.decode("new_state")
        )
    }

    /// Create with information
    /// - Parameters:
    ///   - event: The event
    ///   - entityId: The entity id
    ///   - oldState: The old state, or nil
    ///   - newState: The new state, or nil
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
