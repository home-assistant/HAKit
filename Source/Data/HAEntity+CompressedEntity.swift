import Foundation

extension HAEntity {
    mutating func update(from state: HACompressedEntityState) {
        if let newState = state.state {
            self.state = newState
        }
        lastChanged = state.lastChanged ?? lastChanged
        lastUpdated = state.lastUpdated ?? lastUpdated
        attributes.dictionary = state.attributes ?? attributes.dictionary
        if let contextId = state.context {
            context = .init(id: contextId, userId: nil, parentId: nil)
        }
    }

    mutating func add(_ state: HACompressedEntityState) {
        if let newState = state.state {
            self.state = newState
        }
        lastChanged = state.lastChanged ?? lastChanged
        lastUpdated = state.lastUpdated ?? lastUpdated
        attributes.dictionary.merge(state.attributes ?? [:]) { _, new in new }
        if let contextId = state.context {
            context = .init(id: contextId, userId: nil, parentId: nil)
        }
    }

    mutating func subtract(_ state: HACompressedEntityStateRemove) {
        attributes.dictionary = attributes.dictionary.filter { !(state.attributes?.contains($0.key) ?? false) }
    }
}
