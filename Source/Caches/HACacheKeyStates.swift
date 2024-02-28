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

    /// Process updates from the compressed state to HAEntity
    /// - Parameter info: The compressed state update and the current cached states
    /// - Returns: HAEntity cached states
    /// Logic from: https://github.com/home-assistant/home-assistant-js-websocket/blob/master/lib/entities.ts
    static func processUpdates(info: HACacheTransformInfo<HACompressedStatesUpdates, HACachedStates?>)
        -> HACachedStates {
        var states: HACachedStates = info.current ?? .init(entities: [])

        if let additions = info.incoming.add {
            for (entityId, updates) in additions {
                if var currentState = states[entityId] {
                    currentState.update(from: updates)
                    states[entityId] = currentState
                } else {
                    do {
                        states[entityId] = try updates.asEntity(entityId: entityId)
                    } catch {
                        HAGlobal.log(.error, "[Update-To-Entity-Error] Failed adding new entity: \(error)")
                    }
                }
            }
        }

        if let subtractions = info.incoming.remove {
            for entityId in subtractions {
                states[entityId] = nil
            }
        }

        if let changes = info.incoming.change {
            changes.forEach { entityId, diff in
                guard var entityState = states[entityId] else { return }

                if let toAdd = diff.additions {
                    entityState.add(toAdd)
                    states[entityId] = entityState
                }

                if let toRemove = diff.subtractions {
                    entityState.subtract(toRemove)
                    states[entityId] = entityState
                }
            }
        }

        return states
    }
}
