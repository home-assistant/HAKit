import Foundation

public struct CompressedStatesUpdates: HADataDecodable {
    public let add: [String: CompressedEntityState]?
    public let remove: [String]?
    public let change: [String: CompressedEntityDiff]?

    public init(data: HAData) throws {
        add = try? data.decode("a")
        remove = try? data.decode("r")
        change = try? data.decode("c")
    }
}

public struct CompressedEntityState: HADataDecodable {
    public let state: String
    public let attributes: NSDictionary?
    public let context: String?
    public let lastChanged: Double?
    public let lastUpdated: Double?

    public init(data: HAData) throws {
        state = try data.decode("s")
        attributes = try? data.decode("a")
        context = try? data.decode("c")
        lastChanged = try? data.decode("lc")
        lastUpdated = try? data.decode("lu")
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

    func toEntity(entityId: String) throws -> HAEntity {
        let data = HAData(value: [
            "entity_id": entityId,
            "state": state,
            "last_changed": lastChangedDate ?? Date(),
            "last_updated": lastUpdatedDate ?? Date(),
            "attributes": attributes as? [String: Any] ?? [:],
            "context": ["id": entityId]
        ])
        return try HAEntity(data: data)
    }
}

public struct CompressedEntityStateRemove: HADataDecodable {
    public let attributes: [String]?
    
    public init(data: HAData) throws {
        attributes = try? data.decode("a")
    }
}

public struct CompressedEntityDiff: HADataDecodable {
    public let additions: CompressedEntityState?
    public let subtractions: CompressedEntityStateRemove?

    public init(data: HAData) throws {
        additions = try? data.decode("+")
        subtractions = try? data.decode("-")
    }
}
