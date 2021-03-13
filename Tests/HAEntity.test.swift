@testable import HAKit
import XCTest

internal class HAEntityTests: XCTestCase {
    func testWithInvalidData() throws {
        let data = HAData(value: [:])
        XCTAssertThrowsError(try HAEntity(data: data))
    }

    func testWithInvalidEntityId() throws {
        let data = HAData(testJsonString: """
        {
            "entity_id": "bob",
            "state": "two",
            "attributes": {},
            "last_changed": "2021-02-20T05:14:52.625818+00:00",
            "last_updated": "2021-02-23T05:55:17.008448+00:00",
            "context": {
                "id": "27f121fd8bfa49f92f7094d8cb3eb2c1",
                "parent_id": null,
                "user_id": null
            }
        }
        """)
        XCTAssertThrowsError(try HAEntity(data: data))
    }

    func testWithData() throws {
        let data = HAData(testJsonString: """
        {
            "entity_id": "input_select.muffin",
            "state": "two",
            "attributes": {
                "options": [
                    "one",
                    "two",
                    "three"
                ],
                "editable": true,
                "friendly_name": "muffin",
                "icon": "mdi:light"
            },
            "last_changed": "2021-02-20T05:14:52.625818+00:00",
            "last_updated": "2021-02-23T05:55:17.008448+00:00",
            "context": {
                "id": "27f121fd8bfa49f92f7094d8cb3eb2c1",
                "parent_id": null,
                "user_id": null
            }
        }
        """)
        let entity = try HAEntity(data: data)
        XCTAssertEqual(entity.entityId, "input_select.muffin")
        XCTAssertEqual(entity.domain, "input_select")
        XCTAssertEqual(entity.state, "two")
        XCTAssertEqual(entity.attributes["options"] as? [String], ["one", "two", "three"])
        XCTAssertEqual(entity.attributes["editable"] as? Bool, true)
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "muffin")
        XCTAssertEqual(entity.attributes["icon"] as? String, "mdi:light")

        let changed = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: entity.lastChanged
        )
        XCTAssertEqual(changed.year, 2021)
        XCTAssertEqual(changed.month, 2)
        XCTAssertEqual(changed.day, 20)
        XCTAssertEqual(changed.hour, 5)
        XCTAssertEqual(changed.minute, 14)
        XCTAssertEqual(changed.second, 52)
        XCTAssertEqual(changed.nanosecond ?? -1, 625_000_000, accuracy: 100_000)

        let updated = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: entity.lastUpdated
        )
        XCTAssertEqual(updated.year, 2021)
        XCTAssertEqual(updated.month, 2)
        XCTAssertEqual(updated.day, 23)
        XCTAssertEqual(updated.hour, 5)
        XCTAssertEqual(updated.minute, 55)
        XCTAssertEqual(updated.second, 17)
        XCTAssertEqual(updated.nanosecond ?? -1, 008_000_000, accuracy: 100_000)
    }
}
