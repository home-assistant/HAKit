import Foundation

extension HAEntity {
    func updatedEntity(compressedEntityState: CompressedEntityState) -> HAEntity? {
        try? HAEntity(
            entityId: entityId,
            domain: domain,
            state: compressedEntityState.state,
            lastChanged: compressedEntityState.lastChangedDate ?? lastChanged,
            lastUpdated: compressedEntityState.lastUpdatedDate ?? lastUpdated,
            attributes: (compressedEntityState.attributes as? [String: Any]) ?? attributes.dictionary,
            context: .init(id: compressedEntityState.context ?? "", userId: nil, parentId: nil)
        )
    }

    func updatedEntity(adding compressedEntityState: CompressedEntityState) -> HAEntity? {
        var newAttributes = attributes.dictionary
        (compressedEntityState.attributes as? [String: Any])?.forEach({ key, value in
            newAttributes[key] = value
        })
        return try? HAEntity(
            entityId: entityId,
            domain: domain,
            state: compressedEntityState.state,
            lastChanged: compressedEntityState.lastChangedDate ?? lastChanged,
            lastUpdated: compressedEntityState.lastUpdatedDate ?? lastUpdated,
            attributes:newAttributes,
            context: .init(id: compressedEntityState.context ?? "", userId: nil, parentId: nil)
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
