import Foundation

public struct HACompressedStatesUpdates: HADataDecodable {
    public var add: [String: HACompressedEntityState]?
    public var remove: [String]?
    public var change: [String: CompressedEntityDiff]?

    public init(data: HAData) throws {
        self.add = try? data.decode("a")
        self.remove = try? data.decode("r")
        self.change = try? data.decode("c")
    }
}

public struct HACompressedEntityState: HADataDecodable {
    public var state: String
    public var attributes: [String: Any]?
    public var context: String?
    public var lastChanged: Double?
    public var lastUpdated: Double?

    public init(data: HAData) throws {
        self.state = try data.decode("s")
        self.attributes = try? data.decode("a")
        self.context = try? data.decode("c")
        self.lastChanged = try? data.decode("lc")
        self.lastUpdated = try? data.decode("lu")
    }

    public var lastChangedDate: Date? {
        if let lastChanged {
            return Date(timeIntervalSince1970: lastChanged)
        } else {
            return nil
        }
    }

    public var lastUpdatedDate: Date? {
        if let lastUpdated {
            return Date(timeIntervalSince1970: lastUpdated)
        } else {
            return lastChangedDate
        }
    }

    func asEntity(entityId: String) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: lastChangedDate ?? Date(),
            lastUpdated: lastUpdatedDate ?? Date(),
            attributes: attributes ?? [:],
            context: .init(id: context ?? "", userId: nil, parentId: nil)
        )
    }
}

public struct HACompressedEntityStateRemove: HADataDecodable {
    public var attributes: [String]?

    public init(data: HAData) throws {
        self.attributes = try? data.decode("a")
    }
}

public struct CompressedEntityDiff: HADataDecodable {
    public var additions: HACompressedEntityState?
    public var subtractions: HACompressedEntityStateRemove?

    public init(data: HAData) throws {
        self.additions = try? data.decode("+")
        self.subtractions = try? data.decode("-")
    }
}
