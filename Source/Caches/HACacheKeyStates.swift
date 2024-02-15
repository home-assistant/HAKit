import Foundation

/// Key for the cache
internal struct HACacheKeyStates: HACacheKey {
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
