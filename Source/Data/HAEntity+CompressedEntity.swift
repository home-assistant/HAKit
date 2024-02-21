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
        var newAttributes = attributes.dictionary
        state.attributes?.forEach({ key, value in
            newAttributes[key] = value
        })
        self.state = state.state
        lastChanged = state.lastChanged ?? lastChanged
        lastUpdated = state.lastUpdated ?? lastUpdated
        attributes.dictionary = newAttributes
        context = .init(id: state.context ?? "", userId: nil, parentId: nil)
    }

    mutating func subtract(_ state: HACompressedEntityStateRemove) {
        attributes.dictionary = attributes.dictionary.filter { !(state.attributes?.contains($0.key) ?? false) }
    }
}
