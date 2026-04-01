import HAKit
import XCTest

internal class HADataDecodableTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RandomDecodable.shouldThrow = false
    }

    func testArrayDecodableSuccess() throws {
        let data = HAData.array([.empty, .empty, .empty])
        let result = try [RandomDecodable](data: data)
        XCTAssertEqual(result.count, 3)
    }

    func testArrayDecodableFailureDueToRootData() {
        let data = HAData.dictionary(["key": "value"])
        XCTAssertThrowsError(try [RandomDecodable](data: data)) { error in
            XCTAssertEqual(error as? HADataError, .couldntTransform(key: "root"))
        }
    }

    func testArrayDecodableFailureDueToInside() throws {
        RandomDecodable.shouldThrow = true
        let data = HAData.array([.empty, .empty, .empty])
        XCTAssertThrowsError(try [RandomDecodable](data: data)) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("any"))
        }
    }

    func testHAEntityArrayDecodableSkipsInvalidEntities() throws {
        var logs = [(HAGlobal.LogLevel, String)]()
        HAGlobal.log = { level, message in
            logs.append((level, message))
        }
        defer { HAGlobal.log = { _, _ in } }

        let data = HAData.array([
            entityData(id: "light.valid_one"),
            invalidEntityData(),
            entityData(id: "light.valid_two"),
        ])

        let result = try [HAEntity](data: data)

        XCTAssertEqual(result.map(\.entityId), ["light.valid_one", "light.valid_two"])
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.0, .error)
        XCTAssertTrue(logs.first?.1.starts(with: "[HAEntity-Decode-Error]") == true)
    }

    func testHAEntityArrayDecodeSkipsInvalidEntities() throws {
        var logs = [(HAGlobal.LogLevel, String)]()
        HAGlobal.log = { level, message in
            logs.append((level, message))
        }
        defer { HAGlobal.log = { _, _ in } }

        let data = HAData.dictionary([
            "entities": [
                entityDictionary(id: "light.valid_one"),
                invalidEntityDictionary(),
                entityDictionary(id: "light.valid_two"),
            ],
        ])

        let result: [HAEntity] = try data.decode("entities")

        XCTAssertEqual(result.map(\.entityId), ["light.valid_one", "light.valid_two"])
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.0, .error)
        XCTAssertTrue(logs.first?.1.starts(with: "[HAEntity-Decode-Error]") == true)
    }
}

private class RandomDecodable: HADataDecodable {
    static var shouldThrow = false
    required init(data: HAData) throws {
        if Self.shouldThrow {
            throw HADataError.missingKey("any")
        }
    }
}

private extension HADataDecodableTests {
    func entityData(id: String) -> HAData {
        .dictionary(entityDictionary(id: id))
    }

    func entityDictionary(id: String) -> [String: Any] {
        [
            "entity_id": id,
            "state": "on",
            "attributes": [:],
            "last_changed": "2021-02-20T05:14:52.625818+00:00",
            "last_updated": "2021-02-23T05:55:17.008448+00:00",
            "context": [
                "id": "27f121fd8bfa49f92f7094d8cb3eb2c1",
                "parent_id": NSNull(),
                "user_id": NSNull(),
            ],
        ]
    }

    func invalidEntityData() -> HAData {
        .dictionary(invalidEntityDictionary())
    }

    func invalidEntityDictionary() -> [String: Any] {
        [
            "entity_id": "broken",
            "state": "on",
            "attributes": [:],
            "last_changed": "2021-02-20T05:14:52.625818+00:00",
            "last_updated": "2021-02-23T05:55:17.008448+00:00",
            "context": [
                "id": "27f121fd8bfa49f92f7094d8cb3eb2c1",
                "parent_id": NSNull(),
                "user_id": NSNull(),
            ],
        ]
    }
}
