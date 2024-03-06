public extension HACachesContainer {
    /// Cache of entity states, see `HACachedStates` for values.
    var states: HACache<HACachedStates> { self[HACacheKeyStates.self] }
}

/// Cached version of all entity states
public struct HACachedStates {
    /// All entities
    public var all: Set<HAEntity>
    /// All entities, keyed by their entityId
    public subscript(entityID: String) -> HAEntity? {
        get { allByEntityId[entityID] }
        set { allByEntityId[entityID] = newValue }
    }

    /// Backing dictionary, whose mutation updates the set
    private var allByEntityId: [String: HAEntity] {
        didSet {
            all = Set(allByEntityId.values)
        }
    }

    /// Create a cached state
    /// - Parameter entities: The entities to start with
    public init(entities: [HAEntity]) {
        self.all = Set(entities)
        self.allByEntityId = entities.reduce(into: [:]) { dictionary, entity in
            dictionary[entity.entityId] = entity
        }
    }
}
