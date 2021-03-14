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
        XCTAssertEqual(entity.attributes.friendlyName, "muffin")
        XCTAssertEqual(entity.attributes["icon"] as? String, "mdi:light")
        XCTAssertEqual(entity.attributes.icon, "mdi:light")
        XCTAssertEqual(entity.context.id, "27f121fd8bfa49f92f7094d8cb3eb2c1")
        XCTAssertNil(entity.context.parentId)
        XCTAssertNil(entity.context.userId)

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

    func testWithDataForZone() throws {
        let data = HAData(testJsonString: """
        {
            "entity_id": "zone.south_park",
            "state": "zoning",
            "attributes": {
                "latitude": 37.78163720658547,
                "longitude": -122.3939609527588,
                "radius": 50.0,
                "passive": false,
                "editable": true,
                "friendly_name": "south park",
                "icon": "mdi:map-marker"
            },
            "last_changed": "2021-03-12T18:35:00.997355+00:00",
            "last_updated": "2021-03-12T18:35:00.997355+00:00",
            "context": {
                "id": "1dc14234d6a72d0835abce53d2f62dbd",
                "parent_id": null,
                "user_id": null
            }
        }
        """)
        let entity = try HAEntity(data: data)
        XCTAssertEqual(entity.entityId, "zone.south_park")
        XCTAssertEqual(entity.domain, "zone")
        XCTAssertEqual(entity.state, "zoning")

        XCTAssertEqual(entity.attributes.friendlyName, "south park")
        XCTAssertEqual(entity.attributes.icon, "mdi:map-marker")

        let zoneAttributes = try XCTUnwrap(entity.attributes.zone)
        XCTAssertEqual(zoneAttributes.latitude, 37.78163720658547, accuracy: 0.0000001)
        XCTAssertEqual(zoneAttributes.longitude, -122.3939609527588, accuracy: 0.0000001)
        XCTAssertEqual(zoneAttributes.radius.converted(to: .meters).value, 50.0, accuracy: 0.000001)

        let changed = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: entity.lastChanged
        )
        XCTAssertEqual(changed.year, 2021)
        XCTAssertEqual(changed.month, 3)
        XCTAssertEqual(changed.day, 12)
        XCTAssertEqual(changed.hour, 18)
        XCTAssertEqual(changed.minute, 35)
        XCTAssertEqual(changed.second, 00)
        XCTAssertEqual(changed.nanosecond ?? -1, 997_000_000, accuracy: 100_000)

        let updated = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: entity.lastUpdated
        )
        XCTAssertEqual(updated, changed)
    }
}
