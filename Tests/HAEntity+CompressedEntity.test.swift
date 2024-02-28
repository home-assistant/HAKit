@testable import HAKit
import XCTest

internal final class HAEntity_CompressedEntity_test: XCTestCase {
    func testUpdatedEntityCompressedEntityStateUpdatesEntity() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.kitchen",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_707_933_377.952297)
        try entity.update(
            from: .init(
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

        XCTAssertEqual(entity.state, "off")
        XCTAssertEqual(entity.attributes.dictionary as? [String: String], ["abc": "def"])
        XCTAssertEqual(entity.context.id, "01HPMC69D08CHCWQ76GC69BD3G")
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.lastChanged, expectedDate)
    }

    func testUpdatedEntityAddingCompressedEntityStateAddsToEntity() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.kitchen",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["hello": "world"],
            context: .init(id: "", userId: "", parentId: "")
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_707_933_377.952297)
        try entity.add(
            .init(
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

        XCTAssertEqual(entity.state, "off")
        XCTAssertEqual(entity.attributes.dictionary as? [String: String], ["hello": "world", "abc": "def"])
        XCTAssertEqual(entity.context.id, "01HPMC69D08CHCWQ76GC69BD3G")
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.lastChanged, expectedDate)
    }

    func testUpdatedEntitySubtractingCompressedEntityStateSubtractFromEntity() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.kitchen",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["hello": "world", "abc": "def"],
            context: .init(id: "", userId: "", parentId: "")
        ))
        try entity.subtract(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "off",
                        "a": {
                            "abc": "def"
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.attributes.dictionary as? [String: String], ["hello": "world", "abc": "def"])
    }
}
