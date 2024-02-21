import Foundation

extension HAEntity {
    mutating func update(from state: HACompressedEntityState) {
        self.state = state.state
        lastChanged = state.lastChanged ?? lastChanged
        lastUpdated = state.lastUpdated ?? lastUpdated
        attributes.dictionary = state.attributes ?? attributes.dictionary
        context = .init(id: state.context ?? "", userId: nil, parentId: nil)
    }

    mutating func add(_ state: HACompressedEntityState) {
        self.state = state.state
        lastChanged = state.lastChanged ?? lastChanged
        lastUpdated = state.lastUpdated ?? lastUpdated
        attributes.dictionary.merge(state.attributes ?? [:]) { current, _ in current }
        context = .init(id: state.context ?? "", userId: nil, parentId: nil)
    }

    mutating func subtract(_ state: HACompressedEntityStateRemove) {
        attributes.dictionary = attributes.dictionary.filter { !(state.attributes?.contains($0.key) ?? false) }
    }
}
