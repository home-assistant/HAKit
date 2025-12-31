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

    func testUpdatedEntityAddingCompressedEntityStateUpdatesColorAttributes() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.shapes_106e",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "color_mode": "xy",
                "color_temp_kelvin": 4000,
                "color_temp": 250,
                "brightness": 200,
            ],
            context: .init(id: "01KDR8XXD5FQZ6ZS205EQCEWZ0", userId: "", parentId: "")
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_767_119_976.2438288)

        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "lu": 1767119976.2438288,
                        "c": "01KDR8XXD5FQZ6ZS205EQCEWZ1",
                        "s": "on",
                        "a": {
                            "color_mode": "hs",
                            "color_temp_kelvin": null,
                            "color_temp": null,
                            "hs_color": [218, 50],
                            "rgb_color": [128, 174, 255],
                            "xy_color": [0.208, 0.22]
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.context.id, "01KDR8XXD5FQZ6ZS205EQCEWZ1")

        // Verify updated attributes
        XCTAssertEqual(entity.attributes["color_mode"] as? String, "hs")
        XCTAssertTrue(entity.attributes["color_temp_kelvin"] is NSNull)
        XCTAssertTrue(entity.attributes["color_temp"] is NSNull)

        // Verify new color attributes were added
        let hsColor = entity.attributes["hs_color"] as? [Int]
        XCTAssertEqual(hsColor, [218, 50])

        let rgbColor = entity.attributes["rgb_color"] as? [Int]
        XCTAssertEqual(rgbColor, [128, 174, 255])

        let xyColor = entity.attributes["xy_color"] as? [Double]
        XCTAssertEqual(xyColor.unsafelyUnwrapped[0], 0.208, accuracy: 0.001)
        XCTAssertEqual(xyColor.unsafelyUnwrapped[1], 0.22, accuracy: 0.001)

        // Verify existing attribute that wasn't in the update is preserved
        XCTAssertEqual(entity.attributes["brightness"] as? Int, 200)
    }

    func testUpdatedEntityAddingCompressedEntityStatePreservesUnmentionedAttributes() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.toilet_2_light",
            domain: "light",
            state: "off",
            lastChanged: Date(timeIntervalSince1970: 1_767_121_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_121_000.0),
            attributes: [
                "supported_color_modes": ["brightness", "color_temp", "hs"],
                "color_mode": "color_temp",
                "color_temp_kelvin": 3000,
                "brightness": 128,
                "friendly_name": "Toilet 2 Light",
                "supported_features": 40,
            ],
            context: .init(id: "01KDRA7YE456QMP0E7B4HR12KV", userId: nil, parentId: nil)
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_767_121_353.293047)

        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "on",
                        "lc": 1767121353.293047,
                        "lu": 1767121353.293047,
                        "c": "01KDRA7YE5G832XS65APF5C8WW",
                        "a": {
                            "color_mode": "brightness",
                            "brightness": 255
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.lastChanged, expectedDate)
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.context.id, "01KDRA7YE5G832XS65APF5C8WW")

        // Verify updated attributes
        XCTAssertEqual(entity.attributes["color_mode"] as? String, "brightness")
        XCTAssertEqual(entity.attributes["brightness"] as? Int, 255)

        // Verify ALL unmentioned attributes are preserved
        let supportedColorModes = entity.attributes["supported_color_modes"] as? [String]
        XCTAssertEqual(supportedColorModes, ["brightness", "color_temp", "hs"])
        XCTAssertEqual(entity.attributes["color_temp_kelvin"] as? Int, 3000)
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Toilet 2 Light")
        XCTAssertEqual(entity.attributes["supported_features"] as? Int, 40)
    }

    func testUpdatedEntityWithMultipleAddOperationsPreservesAttributes() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "sensor.temperature",
            domain: "sensor",
            state: "20.5",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "unit_of_measurement": "°C",
                "device_class": "temperature",
                "friendly_name": "Temperature Sensor",
                "min_value": 10.0,
                "max_value": 30.0,
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        ))

        // First update: change state and one attribute
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "21.2",
                        "lu": 1767121353.293047,
                        "c": "02",
                        "a": {
                            "last_updated_timestamp": 1767121353
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "21.2")
        XCTAssertEqual(entity.attributes["last_updated_timestamp"] as? Int, 1767121353)
        // All original attributes should still be there
        XCTAssertEqual(entity.attributes["unit_of_measurement"] as? String, "°C")
        XCTAssertEqual(entity.attributes["device_class"] as? String, "temperature")
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Temperature Sensor")
        XCTAssertEqual(entity.attributes["min_value"] as? Double, 10.0)
        XCTAssertEqual(entity.attributes["max_value"] as? Double, 30.0)

        // Second update: change another attribute
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "22.8",
                        "lu": 1767121453.293047,
                        "c": "03",
                        "a": {
                            "battery_level": 85
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "22.8")
        XCTAssertEqual(entity.attributes["battery_level"] as? Int, 85)
        // Previous added attribute should still be there
        XCTAssertEqual(entity.attributes["last_updated_timestamp"] as? Int, 1767121353)
        // All original attributes should STILL be there
        XCTAssertEqual(entity.attributes["unit_of_measurement"] as? String, "°C")
        XCTAssertEqual(entity.attributes["device_class"] as? String, "temperature")
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Temperature Sensor")
        XCTAssertEqual(entity.attributes["min_value"] as? Double, 10.0)
        XCTAssertEqual(entity.attributes["max_value"] as? Double, 30.0)
    }

    func testUpdateMethodReplacesAllAttributesUnlikeAdd() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.bedroom",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "brightness": 100,
                "color_mode": "hs",
                "hs_color": [120, 75],
                "friendly_name": "Bedroom Light",
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        ))

        // Using update() should REPLACE all attributes
        try entity.update(
            from: .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "off",
                        "lu": 1767121353.293047,
                        "c": "02",
                        "a": {
                            "power_usage": 0
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "off")
        // Only the new attribute should exist
        XCTAssertEqual(entity.attributes["power_usage"] as? Int, 0)
        // All previous attributes should be gone
        XCTAssertNil(entity.attributes["brightness"])
        XCTAssertNil(entity.attributes["color_mode"])
        XCTAssertNil(entity.attributes["hs_color"])
        XCTAssertNil(entity.attributes["friendly_name"])
    }

    func testSubtractOnlyRemovesSpecifiedAttributes() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "media_player.living_room",
            domain: "media_player",
            state: "playing",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "volume_level": 0.5,
                "media_title": "Song Name",
                "media_artist": "Artist Name",
                "media_duration": 240,
                "friendly_name": "Living Room Speaker",
                "supported_features": 12345,
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        ))

        // Subtract specific attributes (like when media stops)
        try entity.subtract(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "a": ["media_title", "media_artist", "media_duration"]
                    }
                    """
                )
            )
        )

        // State should be unchanged (subtract doesn't modify state)
        XCTAssertEqual(entity.state, "playing")

        // Specified attributes should be removed
        XCTAssertNil(entity.attributes["media_title"])
        XCTAssertNil(entity.attributes["media_artist"])
        XCTAssertNil(entity.attributes["media_duration"])

        // Unmentioned attributes should be preserved
        XCTAssertEqual(entity.attributes["volume_level"] as? Double, 0.5)
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Living Room Speaker")
        XCTAssertEqual(entity.attributes["supported_features"] as? Int, 12345)
    }

    func testAddWithNoAttributesOnlyUpdatesStateAndMetadata() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "binary_sensor.door",
            domain: "binary_sensor",
            state: "off",
            lastChanged: Date(timeIntervalSince1970: 1_767_121_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_121_000.0),
            attributes: [
                "device_class": "door",
                "friendly_name": "Front Door",
                "battery_level": 90,
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_767_121_500.0)

        // Update with no attributes provided
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "on",
                        "lc": 1767121500.0,
                        "lu": 1767121500.0,
                        "c": "02"
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.lastChanged, expectedDate)
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.context.id, "02")

        // ALL attributes should be preserved
        XCTAssertEqual(entity.attributes["device_class"] as? String, "door")
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Front Door")
        XCTAssertEqual(entity.attributes["battery_level"] as? Int, 90)
    }

    func testUpdatedEntityAddingCompressedEntityStateReplacesNullAttributesWithValues() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.shapes_106e",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "color_mode": "hs",
                "color_temp_kelvin": NSNull(),
                "color_temp": NSNull(),
                "hs_color": [218, 50],
                "rgb_color": [128, 174, 255],
                "xy_color": [0.208, 0.22],
                "brightness": 255,
                "supported_color_modes": ["brightness", "color_temp", "hs"],
            ],
            context: .init(id: "01KDRA8T75X649PPXB3FCX79F7", userId: nil, parentId: nil)
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_767_121_381.996944)

        // Light switches from HS mode to color temp mode
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "lu": 1767121381.996944,
                        "c": "01KDRA8T75X649PPXB3FCX79F8",
                        "s": "on",
                        "a": {
                            "color_mode": "color_temp",
                            "color_temp_kelvin": 1200,
                            "color_temp": 833,
                            "hs_color": [20.248, 100.0],
                            "rgb_color": [255, 86, 0],
                            "xy_color": [0.658, 0.335]
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.context.id, "01KDRA8T75X649PPXB3FCX79F8")

        // Verify color mode switched
        XCTAssertEqual(entity.attributes["color_mode"] as? String, "color_temp")

        // Verify previously null attributes now have values
        XCTAssertEqual(entity.attributes["color_temp_kelvin"] as? Int, 1200)
        XCTAssertEqual(entity.attributes["color_temp"] as? Int, 833)

        // Verify color attributes were updated with new values
        let hsColor = entity.attributes["hs_color"] as? [Double]
        XCTAssertEqual(hsColor.unsafelyUnwrapped[0], 20.248, accuracy: 0.001)
        XCTAssertEqual(hsColor.unsafelyUnwrapped[1], 100.0, accuracy: 0.001)

        let rgbColor = entity.attributes["rgb_color"] as? [Int]
        XCTAssertEqual(rgbColor, [255, 86, 0])

        let xyColor = entity.attributes["xy_color"] as? [Double]
        XCTAssertEqual(xyColor.unsafelyUnwrapped[0], 0.658, accuracy: 0.001)
        XCTAssertEqual(xyColor.unsafelyUnwrapped[1], 0.335, accuracy: 0.001)

        // Verify unmentioned attributes are preserved
        XCTAssertEqual(entity.attributes["brightness"] as? Int, 255)
        let supportedColorModes = entity.attributes["supported_color_modes"] as? [String]
        XCTAssertEqual(supportedColorModes, ["brightness", "color_temp", "hs"])
    }

    func testAddWithoutStateFieldOnlyUpdatesAttributes() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "light.shapes_106e",
            domain: "light",
            state: "on",
            lastChanged: Date(timeIntervalSince1970: 1_767_184_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_184_000.0),
            attributes: [
                "brightness": 255,
                "color_mode": "xy",
                "hs_color": [120, 75],
                "rgb_color": [100, 200, 150],
                "xy_color": [0.3, 0.4],
            ],
            context: .init(id: "01KDRT6BX126597T7MSK9V32NG8", userId: nil, parentId: nil)
        ))
        let expectedDate = Date(timeIntervalSince1970: 1_767_184_397.9635696)

        // Change event with no state field - should only update attributes
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "lu": 1767184397.9635696,
                        "c": "01KDT6BX126597T7MSK9V32NG9",
                        "a": {
                            "color_mode": "hs",
                            "color_temp_kelvin": null,
                            "color_temp": null,
                            "hs_color": [218, 50],
                            "rgb_color": [128, 174, 255],
                            "xy_color": [0.208, 0.22]
                        }
                    }
                    """
                )
            )
        )

        // State should remain unchanged
        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.lastUpdated, expectedDate)
        XCTAssertEqual(entity.context.id, "01KDT6BX126597T7MSK9V32NG9")

        // Verify updated attributes
        XCTAssertEqual(entity.attributes["color_mode"] as? String, "hs")
        XCTAssertTrue(entity.attributes["color_temp_kelvin"] is NSNull)
        XCTAssertTrue(entity.attributes["color_temp"] is NSNull)

        // Verify color attributes were updated
        let hsColor = entity.attributes["hs_color"] as? [Int]
        XCTAssertEqual(hsColor, [218, 50])

        let rgbColor = entity.attributes["rgb_color"] as? [Int]
        XCTAssertEqual(rgbColor, [128, 174, 255])

        let xyColor = entity.attributes["xy_color"] as? [Double]
        XCTAssertEqual(xyColor.unsafelyUnwrapped[0], 0.208, accuracy: 0.001)
        XCTAssertEqual(xyColor.unsafelyUnwrapped[1], 0.22, accuracy: 0.001)

        // Verify existing unmentioned attribute is preserved
        XCTAssertEqual(entity.attributes["brightness"] as? Int, 255)
    }

    func testAddAndSubtractCombinedWorkflow() throws {
        var entity = try XCTUnwrap(HAEntity(
            entityId: "climate.thermostat",
            domain: "climate",
            state: "heat",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "current_temperature": 20.0,
                "target_temperature": 22.0,
                "hvac_mode": "heat",
                "fan_mode": "auto",
                "swing_mode": "off",
                "preset_mode": "home",
                "friendly_name": "Living Room Thermostat",
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        ))

        // Add some temporary attributes (like when auxiliary heat is on)
        try entity.add(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "s": "heat",
                        "lu": 1767121353.293047,
                        "c": "02",
                        "a": {
                            "current_temperature": 20.5,
                            "aux_heat": "on",
                            "aux_heat_target": 25.0
                        }
                    }
                    """
                )
            )
        )

        XCTAssertEqual(entity.attributes["current_temperature"] as? Double, 20.5)
        XCTAssertEqual(entity.attributes["aux_heat"] as? String, "on")
        XCTAssertEqual(entity.attributes["aux_heat_target"] as? Double, 25.0)
        // Original attributes still there
        XCTAssertEqual(entity.attributes["target_temperature"] as? Double, 22.0)
        XCTAssertEqual(entity.attributes["preset_mode"] as? String, "home")

        // Now subtract the auxiliary heat attributes
        try entity.subtract(
            .init(
                data:
                .init(
                    testJsonString:
                    """
                    {
                        "a": ["aux_heat", "aux_heat_target"]
                    }
                    """
                )
            )
        )

        // Auxiliary attributes should be gone
        XCTAssertNil(entity.attributes["aux_heat"])
        XCTAssertNil(entity.attributes["aux_heat_target"])

        // But everything else should still be there
        XCTAssertEqual(entity.attributes["current_temperature"] as? Double, 20.5)
        XCTAssertEqual(entity.attributes["target_temperature"] as? Double, 22.0)
        XCTAssertEqual(entity.attributes["hvac_mode"] as? String, "heat")
        XCTAssertEqual(entity.attributes["fan_mode"] as? String, "auto")
        XCTAssertEqual(entity.attributes["swing_mode"] as? String, "off")
        XCTAssertEqual(entity.attributes["preset_mode"] as? String, "home")
        XCTAssertEqual(entity.attributes["friendly_name"] as? String, "Living Room Thermostat")
    }
}
