public extension HACachesContainer {
    /// Cache of entity states, see `HACachedStates` for values.
    var states: HACache<HACachedStates> { self[HACacheKeyStates.self] }
}

/// Key for the cache
private struct HACacheKeyStates: HACacheKey {
    static func create(connection: HAConnection) -> HACache<HACachedStates> {
        .init(
            connection: connection,
            subscribe:
                    .init(
                        subscription: .subscribeEntities(),
                        transform: { info in
                                .replace(processUpdates(info: info))
                        }
                    )
        )
    }

    /// Logic from: https://github.com/home-assistant/home-assistant-js-websocket/blob/master/lib/entities.ts
    static func processUpdates(info: HACacheTransformInfo<CompressedStatesUpdates, HACachedStates?>) -> HACachedStates {
        var states = info.current ?? .init(entities: [])

        if let additions = info.incoming.add {
            additions.forEach { entityId, updates in
                if let currentState = states[entityId] {
                    if let updatedEntity = currentState.updatedEntity(compressedEntityState: updates) {
                        states[entityId] = updatedEntity
                    }
                } else {
                    do {
                        states[entityId] = try updates.toEntity(entityId: entityId)
                    } catch let error {
                        print(error)
                    }
                }
            }
        }

        if let subtractions = info.incoming.remove {
            subtractions.forEach { entityId in
                states[entityId] = nil
            }
        }

        if let changes = info.incoming.change {
            changes.forEach { entityId, diff in
                guard let entityState = states[entityId] else { return }

                if let toAdd = diff.additions {
                    if let updateEntity = entityState.updatedEntity(adding: toAdd) {
                        states[entityId] = updateEntity
                    }
                }

                if let toRemove = diff.subtractions {
                    if let updateEntity = entityState.updatedEntity(subtracting: toRemove) {
                        states[entityId] = updateEntity
                    }
                }
            }
        }
        
        return states
    }
}

extension HAEntity {
    func updatedEntity(compressedEntityState: CompressedEntityState) -> HAEntity? {
        try? HAEntity(
            entityId: entityId,
            domain: domain,
            state: compressedEntityState.state,
            lastChanged: compressedEntityState.lastChangedDate ?? lastChanged,
            lastUpdated: compressedEntityState.lastUpdatedDate ?? lastUpdated,
            attributes: compressedEntityState.attributes?.dictionary ?? attributes.dictionary,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }

    func updatedEntity(adding compressedEntityState: CompressedEntityState) -> HAEntity? {
        var newAttributes = attributes.dictionary
        compressedEntityState.attributes?.dictionary.forEach({ key, value in
            newAttributes[key] = value
        })
        return try? HAEntity(
            entityId: entityId,
            domain: domain,
            state: compressedEntityState.state,
            lastChanged: compressedEntityState.lastChangedDate ?? lastChanged,
            lastUpdated: compressedEntityState.lastUpdatedDate ?? lastUpdated,
            attributes:newAttributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }

    func updatedEntity(subtracting compressedEntityStateRemove: CompressedEntityStateRemove) -> HAEntity? {
        try? HAEntity(
            entityId: entityId,
            domain: domain,
            state: state,
            lastChanged: lastChanged,
            lastUpdated: lastUpdated,
            attributes: attributes.dictionary.filter({  !(compressedEntityStateRemove.attributes?.contains($0.key) ?? false)  }),
            context: context
        )
    }
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
