@testable import HAKit
import XCTest

final class HAEntity_CompressedEntity_test: XCTestCase {

    func test_updatedEntity_compressedEntityState_updatesEntity() throws {
        let entity = try XCTUnwrap(HAEntity(entityId: "light.kitchen", domain: "light", state: "on", lastChanged: Date(), lastUpdated: Date(), attributes: [:], context: .init(id: "", userId: "", parentId: "")))
        let expectedDate = Date(timeIntervalSince1970: 1707933377.952297)
        let updatedEntity = entity.updatedEntity(
            compressedEntityState: try .init(
                data:
                        .init(
                            testJsonString:
"""
{
    "s": "off",
    "a": {
        "abc": "def"
    },
    "c": "01HPMC69D08CHCWQ76GC69BD3G",
    "lc": 1707933377.952297,
    "lu": 1707933377.952297
}
"""
                        )
            )
        )

        XCTAssertEqual(updatedEntity?.state, "off")
        XCTAssertEqual(updatedEntity?.attributes.dictionary as! [String : String], ["abc": "def"])
        XCTAssertEqual(updatedEntity?.context.id, "01HPMC69D08CHCWQ76GC69BD3G")
        XCTAssertEqual(updatedEntity?.lastUpdated, expectedDate)
        XCTAssertEqual(updatedEntity?.lastChanged, expectedDate)
    }

    func test_updatedEntity_adding_compressedEntityState_addsToEntity() throws {
        let entity = try XCTUnwrap(HAEntity(entityId: "light.kitchen", domain: "light", state: "on", lastChanged: Date(), lastUpdated: Date(), attributes: ["hello": "world"], context: .init(id: "", userId: "", parentId: "")))
        let expectedDate = Date(timeIntervalSince1970: 1707933377.952297)
        let updatedEntity = entity.updatedEntity(
            adding: try .init(
                data:
                        .init(
                            testJsonString:
"""
{
    "s": "off",
    "a": {
        "abc": "def"
    },
    "c": "01HPMC69D08CHCWQ76GC69BD3G",
    "lc": 1707933377.952297,
    "lu": 1707933377.952297
}
"""
                        )
            )
        )

        XCTAssertEqual(updatedEntity?.state, "off")
        XCTAssertEqual(updatedEntity?.attributes.dictionary as! [String : String], ["hello": "world", "abc": "def"])
        XCTAssertEqual(updatedEntity?.context.id, "01HPMC69D08CHCWQ76GC69BD3G")
        XCTAssertEqual(updatedEntity?.lastUpdated, expectedDate)
        XCTAssertEqual(updatedEntity?.lastChanged, expectedDate)
    }

    func test_updatedEntity_subtracting_compressedEntityState_subtractFromEntity() throws {
        let entity = try XCTUnwrap(HAEntity(entityId: "light.kitchen", domain: "light", state: "on", lastChanged: Date(), lastUpdated: Date(), attributes: ["hello": "world", "abc": "def"], context: .init(id: "", userId: "", parentId: "")))
        let expectedDate = Date(timeIntervalSince1970: 1707933377.952297)
        let updatedEntity = entity.updatedEntity(
            adding: try .init(
                data:
                        .init(
                            testJsonString:
"""
{
    "s": "off",
    "a": {
        "abc": "def"
    },
    "c": "01HPMC69D08CHCWQ76GC69BD3G",
    "lc": 1707933377.952297,
    "lu": 1707933377.952297
}
"""
                        )
            )
        )

        XCTAssertEqual(updatedEntity?.state, "off")
        XCTAssertEqual(updatedEntity?.attributes.dictionary as! [String : String], ["hello": "world", "abc": "def"])
        XCTAssertEqual(updatedEntity?.context.id, "01HPMC69D08CHCWQ76GC69BD3G")
        XCTAssertEqual(updatedEntity?.lastUpdated, expectedDate)
        XCTAssertEqual(updatedEntity?.lastChanged, expectedDate)
    }
}
