import Foundation

public struct HACompressedStatesUpdates: HADataDecodable {
    public var add: [String: HACompressedEntityState]?
    public var remove: [String]?
    public var change: [String: HACompressedEntityDiff]?

    public init(data: HAData) throws {
        self.add = try? data.decode("a")
        self.remove = try? data.decode("r")
        self.change = try? data.decode("c")
    }
}

public struct HACompressedEntityState: HADataDecodable {
    public var state: String?
    public var attributes: [String: Any]?
    public var context: String?
    public var lastChanged: Date?
    public var lastUpdated: Date?

    public init(data: HAData) throws {
        self.state = try? data.decode("s")
        self.attributes = try? data.decode("a")
        self.context = try? data.decode("c")
        self.lastChanged = try? data.decode("lc")
        self.lastUpdated = try? data.decode("lu")
    }

    func asEntity(entityId: String) throws -> HAEntity {
        guard let state else {
            throw HADataError.couldntTransform(key: "s")
        }
        return try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: lastChanged ?? Date(),
            lastUpdated: lastUpdated ?? Date(),
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

public struct HACompressedEntityDiff: HADataDecodable {
    public var additions: HACompressedEntityState?
    public var subtractions: HACompressedEntityStateRemove?

    public init(data: HAData) throws {
        self.additions = try? data.decode("+")
        self.subtractions = try? data.decode("-")
    }
}
