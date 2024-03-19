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
                    .replace(processUpdates(
                        info: info,
                        shouldResetEntities: info.subscriptionPhase == .initial
                    ))
                }
            )
        )
    }

    /// Process updates from the compressed state to HAEntity
    /// - Parameters:
    ///   - info: The compressed state update and the current cached states
    ///   - shouldResetEntities: True if current state needs to be ignored (e.g. re-connection)
    /// - Returns: HAEntity cached states
    /// Logic from: https://github.com/home-assistant/home-assistant-js-websocket/blob/master/lib/entities.ts
    // swiftlint: disable cyclomatic_complexity
    static func processUpdates(
        info: HACacheTransformInfo<HACompressedStatesUpdates, HACachedStates?>,
        shouldResetEntities: Bool
    ) -> HACachedStates {
        var updatedEntities: [String: HAEntity] = [:]

        if !shouldResetEntities, let currentEntities = info.current {
            updatedEntities = currentEntities.allByEntityId
        }

        if let additions = info.incoming.add {
            for (entityId, updates) in additions {
                if var currentState = updatedEntities[entityId] {
                    currentState.update(from: updates)
                    updatedEntities[entityId] = currentState
                } else {
                    do {
                        let newEntity = try updates.asEntity(entityId: entityId)
                        updatedEntities[entityId] = newEntity
                    } catch {
                        HAGlobal.log(.error, "[Update-To-Entity-Error] Failed adding new entity: \(error)")
                    }
                }
            }
        }

        if let subtractions = info.incoming.remove {
            for entityId in subtractions {
                updatedEntities.removeValue(forKey: entityId)
            }
        }

        if let changes = info.incoming.change {
            for (entityId, diff) in changes {
                guard var entityState = updatedEntities[entityId] else { continue }

                if let toAdd = diff.additions {
                    entityState.add(toAdd)
                }

                if let toRemove = diff.subtractions {
                    entityState.subtract(toRemove)
                }

                updatedEntities[entityId] = entityState
            }
        }

        return .init(entitiesDictionary: updatedEntities)
    }
}
