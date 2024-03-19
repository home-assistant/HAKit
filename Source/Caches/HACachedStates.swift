public extension HACachesContainer {
    /// Cache of entity states, see `HACachedStates` for values.
    var states: HACache<HACachedStates> { self[HACacheKeyStates.self] }
}

/// Cached version of all entity states
public struct HACachedStates {
    /// All entities
    public var all: Set<HAEntity> = []
    /// All entities, keyed by their entityId
    public subscript(entityID: String) -> HAEntity? {
        get { allByEntityId[entityID] }
        set { allByEntityId[entityID] = newValue }
    }

    /// Backing dictionary, whose mutation updates the set
    internal var allByEntityId: [String: HAEntity] {
        didSet {
            all = Set(allByEntityId.values)
        }
    }

    /// Create a cached state
    /// - Parameter entitiesDictionary: The entities to start with, key is the entity ID
    public init(entitiesDictionary: [String: HAEntity]) {
        self.all = Set(entitiesDictionary.values)
        self.allByEntityId = entitiesDictionary
    }

    /// Create a cached state
    /// Mainly for tests
    /// - Parameter entities: The entities to start with
    internal init(entities: [HAEntity]) {
        self.all = Set(entities)
        self.allByEntityId = entities.reduce(into: [:]) { dictionary, entity in
            dictionary[entity.entityId] = entity
        }
    }
}
