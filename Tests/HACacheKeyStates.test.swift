@testable import HAKit
import XCTest

internal final class HACacheKeyStates_test: XCTestCase {
    func testProcessUpdatesAddNewEntities() throws {
        let expectedDate = Date(timeIntervalSince1970: 1_707_884_643.671705)
        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "a": {
                                "person.bruno": {
                                    "s": "not_home",
                                    "a": {
                                        "editable": true,
                                        "id": "bruno",
                                        "latitude": 51,
                                        "longitude": 4,
                                        "gps_accuracy": 14,
                                        "source": "device_tracker.iphone",
                                        "user_id": "aaba1f0197f84e68bb39142e2884b652",
                                        "device_trackers": [
                                            "device_tracker.iphone_15_pro"
                                        ],
                                        "friendly_name": "Bruno"
                                    },
                                    "c": "01HPKH5TE4HVR88WW6TN43H31X",
                                    "lc": 1707884643.671705,
                                    "lu": 1707884643.671705
                                },
                                "update.home_assistant_supervisor_update": {
                                    "s": "off",
                                    "a": {
                                        "auto_update": true,
                                        "installed_version": "2024.02.0.dev1205",
                                        "in_progress": false,
                                        "latest_version": "2024.02.0.dev1205",
                                        "release_summary": null,
                                        "release_url": "https://github.com/home-assistant/supervisor/commits/main",
                                        "skipped_version": null,
                                        "title": "Home Assistant Supervisor",
                                        "entity_picture": "https://brands.home-assistant.io/hassio/icon.png",
                                        "friendly_name": "Home Assistant Supervisor Update",
                                        "supported_features": 1
                                    },
                                    "c": "01HPJXQ81Y9P7CFTY7M9807KWZ",
                                    "lc": 1707884643.671705
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [:]
                )
            ), shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 2)
        guard let firstEntity = result.all.first(where: { $0.entityId == "person.bruno" }) else {
            XCTFail("person.bruno entity couldn't be found in result")
            return
        }
        XCTAssertEqual(firstEntity.attributes.dictionary as? [String: AnyHashable], [
            "editable": true,
            "id": "bruno",
            "latitude": 51,
            "longitude": 4,
            "gps_accuracy": 14,
            "source": "device_tracker.iphone",
            "user_id": "aaba1f0197f84e68bb39142e2884b652",
            "device_trackers": [
                "device_tracker.iphone_15_pro",
            ],
            "friendly_name": "Bruno",
        ])
        XCTAssertEqual(firstEntity.context.id, "01HPKH5TE4HVR88WW6TN43H31X")
        XCTAssertEqual(firstEntity.lastChanged, expectedDate)
        XCTAssertEqual(firstEntity.lastUpdated, expectedDate)
    }

    func testProcessUpdatesUpdateExistentEntity() throws {
        let expectedDate = Date(timeIntervalSince1970: 1_707_884_643.671705)
        let existentEntity = try HAEntity(data: .init(
            testJsonString:
            """
            {
                "entity_id": "person.bruno",
                "state": "home",
                "last_changed": "2024-02-16T04:14:29.089664+00:00",
                "last_updated": "2024-02-16T04:14:29.089664+00:00",
                "attributes": {},
                "context": {
                    "id": "123"
                }
            }
            """
        ))
        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "a": {
                                "person.bruno": {
                                    "s": "not_home",
                                    "a": {
                                        "editable": true,
                                        "id": "bruno",
                                        "latitude": 51,
                                        "longitude": 4,
                                        "gps_accuracy": 14,
                                        "source": "device_tracker.iphone",
                                        "user_id": "aaba1f0197f84e68bb39142e2884b652",
                                        "device_trackers": [
                                            "device_tracker.iphone_15_pro"
                                        ],
                                        "friendly_name": "Bruno"
                                    },
                                    "c": "01HPKH5TE4HVR88WW6TN43H31X",
                                    "lc": 1707884643.671705,
                                    "lu": 1707884643.671705
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "person.bruno": existentEntity,
                    ]
                )
            ), shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 1)
        guard let firstEntity = result.all.first(where: { $0.entityId == "person.bruno" }) else {
            XCTFail("person.bruno entity couldn't be found in result")
            return
        }
        XCTAssertEqual(firstEntity.attributes.dictionary as? [String: AnyHashable], [
            "editable": true,
            "id": "bruno",
            "latitude": 51,
            "longitude": 4,
            "gps_accuracy": 14,
            "source": "device_tracker.iphone",
            "user_id": "aaba1f0197f84e68bb39142e2884b652",
            "device_trackers": [
                "device_tracker.iphone_15_pro",
            ],
            "friendly_name": "Bruno",
        ])
        XCTAssertEqual(firstEntity.context.id, "01HPKH5TE4HVR88WW6TN43H31X")
        XCTAssertEqual(firstEntity.lastChanged, expectedDate)
        XCTAssertEqual(firstEntity.lastUpdated, expectedDate)
    }

    func testProcessUpdatesSubtractChanges() throws {
        let existentEntity = try HAEntity(data: .init(
            testJsonString:
            """
            {
                "entity_id": "person.bruno",
                "state": "home",
                "last_changed": "2024-02-16T04:14:29.089664+00:00",
                "last_updated": "2024-02-16T04:14:29.089664+00:00",
                "attributes": {
                    "editable": true
            },
                "context": {
                    "id": "123"
                }
            }
            """
        ))
        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "person.bruno": {
                                    "-": {
                                        "a": [
                                            "editable"
                                        ]
                                    }
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "person.bruno": existentEntity,
                    ]
                )
            ), shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 1)
        guard let firstEntity = result.all.first else {
            XCTFail("person.bruno entity couldn't be found in result")
            return
        }
        XCTAssertEqual(firstEntity.attributes.dictionary as? [String: AnyHashable], [:])
    }

    func testProcessUpdatesAddNewEntitiesWhenEntityCantBeConvertedFromUpdate() throws {
        let expectation = expectation(description: "Wait for error log")

        HAGlobal.log = { level, message in
            XCTAssertEqual(level, .error)
            XCTAssertTrue(message.starts(with: "[Update-To-Entity-Error]"))
            // Reset log implementation
            HAGlobal.log = { _, _ in }
            expectation.fulfill()
        }

        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "a": {
                                "wrong_entity_name_without_domain": {
                                    "s": "not_home",
                                    "a": {
                                        "editable": true
                                    },
                                    "c": "01HPKH5TE4HVR88WW6TN43H31X",
                                    "lc": 1707884643.671705,
                                    "lu": 1707884643.671705
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [:]
                )
            ), shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 0)
        wait(for: [expectation])
    }

    func testProcessUpdatesLightEntityWithAttributeChanges() throws {
        // Initial light entity state
        let initialEntity = try HAEntity(
            entityId: "light.shapes_106e",
            domain: "light",
            state: "on",
            lastChanged: Date(timeIntervalSince1970: 1_767_119_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_119_000.0),
            attributes: [
                "min_color_temp_kelvin": 1200,
                "max_color_temp_kelvin": 6535,
                "min_mireds": 153,
                "max_mireds": 833,
                "supported_color_modes": ["color_temp", "hs"],
                "color_mode": "color_temp",
                "brightness": 255,
                "color_temp_kelvin": 4000,
                "color_temp": 250,
                "hs_color": [20.248, 100.0],
                "rgb_color": [255, 86, 0],
                "xy_color": [0.658, 0.335],
                "friendly_name": "Shapes 106e",
                "supported_features": 44,
            ],
            context: .init(id: "01KDR8XXD5FQZ6ZS205EQCEWZ0", userId: nil, parentId: nil)
        )

        // First update: Switch to HS color mode with null color temps
        let result1 = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "light.shapes_106e": {
                                    "+": {
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
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "light.shapes_106e": initialEntity,
                    ]
                )
            ),
            shouldResetEntities: false
        )

        XCTAssertEqual(result1.all.count, 1)
        guard let entity1 = result1.all.first else {
            XCTFail("light.shapes_106e entity couldn't be found in result")
            return
        }

        // Verify state after first update
        XCTAssertEqual(entity1.state, "on")
        XCTAssertEqual(entity1.lastUpdated, Date(timeIntervalSince1970: 1_767_119_976.2438288))
        XCTAssertEqual(entity1.context.id, "01KDR8XXD5FQZ6ZS205EQCEWZ1")

        // Verify color mode changed and color temps are now null
        XCTAssertEqual(entity1.attributes["color_mode"] as? String, "hs")
        XCTAssertTrue(entity1.attributes["color_temp_kelvin"] is NSNull)
        XCTAssertTrue(entity1.attributes["color_temp"] is NSNull)

        // Verify new HS color values
        let hsColor1 = entity1.attributes["hs_color"] as? [Int]
        XCTAssertEqual(hsColor1, [218, 50])

        let rgbColor1 = entity1.attributes["rgb_color"] as? [Int]
        XCTAssertEqual(rgbColor1, [128, 174, 255])

        let xyColor1 = entity1.attributes["xy_color"] as? [Double]
        XCTAssertEqual(xyColor1.unsafelyUnwrapped[0], 0.208, accuracy: 0.001)
        XCTAssertEqual(xyColor1.unsafelyUnwrapped[1], 0.22, accuracy: 0.001)

        // Verify unmentioned attributes were preserved from initial state
        XCTAssertEqual(entity1.attributes["brightness"] as? Int, 255)
        XCTAssertEqual(entity1.attributes["friendly_name"] as? String, "Shapes 106e")
        XCTAssertEqual(entity1.attributes["supported_features"] as? Int, 44)
        XCTAssertEqual(entity1.attributes["min_color_temp_kelvin"] as? Int, 1200)
        XCTAssertEqual(entity1.attributes["max_color_temp_kelvin"] as? Int, 6535)
        let supportedColorModes = entity1.attributes["supported_color_modes"] as? [String]
        XCTAssertEqual(supportedColorModes, ["color_temp", "hs"])

        // Second update: Switch back to color_temp mode
        let result2 = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "light.shapes_106e": {
                                    "+": {
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
                                }
                            }
                        }
                        """
                    )
                ),
                current: result1
            ),
            shouldResetEntities: false
        )

        XCTAssertEqual(result2.all.count, 1)
        guard let entity2 = result2.all.first else {
            XCTFail("light.shapes_106e entity couldn't be found in result")
            return
        }

        // Verify state after second update
        XCTAssertEqual(entity2.state, "on")
        XCTAssertEqual(entity2.lastUpdated, Date(timeIntervalSince1970: 1_767_121_381.996944))
        XCTAssertEqual(entity2.context.id, "01KDRA8T75X649PPXB3FCX79F8")

        // Verify color mode changed back and color temps have values again
        XCTAssertEqual(entity2.attributes["color_mode"] as? String, "color_temp")
        XCTAssertEqual(entity2.attributes["color_temp_kelvin"] as? Int, 1200)
        XCTAssertEqual(entity2.attributes["color_temp"] as? Int, 833)

        // Verify color values updated
        let hsColor2 = entity2.attributes["hs_color"] as? [Double]
        XCTAssertEqual(hsColor2.unsafelyUnwrapped[0], 20.248, accuracy: 0.001)
        XCTAssertEqual(hsColor2.unsafelyUnwrapped[1], 100.0, accuracy: 0.001)

        let rgbColor2 = entity2.attributes["rgb_color"] as? [Int]
        XCTAssertEqual(rgbColor2, [255, 86, 0])

        let xyColor2 = entity2.attributes["xy_color"] as? [Double]
        XCTAssertEqual(xyColor2.unsafelyUnwrapped[0], 0.658, accuracy: 0.001)
        XCTAssertEqual(xyColor2.unsafelyUnwrapped[1], 0.335, accuracy: 0.001)

        // Verify all static attributes STILL preserved through both updates
        XCTAssertEqual(entity2.attributes["brightness"] as? Int, 255)
        XCTAssertEqual(entity2.attributes["friendly_name"] as? String, "Shapes 106e")
        XCTAssertEqual(entity2.attributes["supported_features"] as? Int, 44)
        XCTAssertEqual(entity2.attributes["min_color_temp_kelvin"] as? Int, 1200)
        XCTAssertEqual(entity2.attributes["max_color_temp_kelvin"] as? Int, 6535)
        let supportedColorModes2 = entity2.attributes["supported_color_modes"] as? [String]
        XCTAssertEqual(supportedColorModes2, ["color_temp", "hs"])
    }

    func testProcessUpdatesMultipleLightEntityChanges() throws {
        // Initial entities
        let lightEntity = try HAEntity(
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
        )

        let sensorEntity = try HAEntity(
            entityId: "sensor.temperature",
            domain: "sensor",
            state: "20.5",
            lastChanged: Date(timeIntervalSince1970: 1_767_121_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_121_000.0),
            attributes: [
                "unit_of_measurement": "°C",
                "device_class": "temperature",
                "friendly_name": "Temperature Sensor",
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        )

        // Multiple entity changes in one update
        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "light.toilet_2_light": {
                                    "+": {
                                        "s": "on",
                                        "lc": 1767121353.293047,
                                        "lu": 1767121353.293047,
                                        "c": "01KDRA7YE5G832XS65APF5C8WW",
                                        "a": {
                                            "color_mode": "brightness",
                                            "brightness": 255
                                        }
                                    }
                                },
                                "sensor.temperature": {
                                    "+": {
                                        "s": "21.8",
                                        "lu": 1767121353.5,
                                        "c": "02",
                                        "a": {
                                            "last_updated_timestamp": 1767121353
                                        }
                                    }
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "light.toilet_2_light": lightEntity,
                        "sensor.temperature": sensorEntity,
                    ]
                )
            ),
            shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 2)

        // Verify light entity
        guard let updatedLight = result.all.first(where: { $0.entityId == "light.toilet_2_light" }) else {
            XCTFail("light.toilet_2_light entity couldn't be found in result")
            return
        }

        XCTAssertEqual(updatedLight.state, "on")
        XCTAssertEqual(updatedLight.lastChanged, Date(timeIntervalSince1970: 1_767_121_353.293047))
        XCTAssertEqual(updatedLight.context.id, "01KDRA7YE5G832XS65APF5C8WW")
        XCTAssertEqual(updatedLight.attributes["color_mode"] as? String, "brightness")
        XCTAssertEqual(updatedLight.attributes["brightness"] as? Int, 255)

        // Verify unmentioned light attributes preserved
        let supportedColorModes = updatedLight.attributes["supported_color_modes"] as? [String]
        XCTAssertEqual(supportedColorModes, ["brightness", "color_temp", "hs"])
        XCTAssertEqual(updatedLight.attributes["color_temp_kelvin"] as? Int, 3000)
        XCTAssertEqual(updatedLight.attributes["friendly_name"] as? String, "Toilet 2 Light")
        XCTAssertEqual(updatedLight.attributes["supported_features"] as? Int, 40)

        // Verify sensor entity
        guard let updatedSensor = result.all.first(where: { $0.entityId == "sensor.temperature" }) else {
            XCTFail("sensor.temperature entity couldn't be found in result")
            return
        }

        XCTAssertEqual(updatedSensor.state, "21.8")
        XCTAssertEqual(updatedSensor.lastUpdated, Date(timeIntervalSince1970: 1_767_121_353.5))
        XCTAssertEqual(updatedSensor.context.id, "02")
        XCTAssertEqual(updatedSensor.attributes["last_updated_timestamp"] as? Int, 1_767_121_353)

        // Verify original sensor attributes preserved
        XCTAssertEqual(updatedSensor.attributes["unit_of_measurement"] as? String, "°C")
        XCTAssertEqual(updatedSensor.attributes["device_class"] as? String, "temperature")
        XCTAssertEqual(updatedSensor.attributes["friendly_name"] as? String, "Temperature Sensor")
    }

    func testProcessUpdatesCombinedAddChangeRemove() throws {
        // Existing entity that will be changed
        let existingLight = try HAEntity(
            entityId: "light.bedroom",
            domain: "light",
            state: "on",
            lastChanged: Date(timeIntervalSince1970: 1_767_121_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_121_000.0),
            attributes: [
                "brightness": 200,
                "color_mode": "hs",
                "friendly_name": "Bedroom Light",
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        )

        // Existing entity that will be removed
        let removedSensor = try HAEntity(
            entityId: "sensor.old_temp",
            domain: "sensor",
            state: "20.0",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "02", userId: nil, parentId: nil)
        )

        let result = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "a": {
                                "light.new_light": {
                                    "s": "on",
                                    "a": {
                                        "brightness": 255,
                                        "friendly_name": "New Light"
                                    },
                                    "c": "03",
                                    "lc": 1767121500.0,
                                    "lu": 1767121500.0
                                }
                            },
                            "r": ["sensor.old_temp"],
                            "c": {
                                "light.bedroom": {
                                    "+": {
                                        "s": "off",
                                        "lu": 1767121500.0,
                                        "c": "04",
                                        "a": {
                                            "brightness": 0
                                        }
                                    }
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "light.bedroom": existingLight,
                        "sensor.old_temp": removedSensor,
                    ]
                )
            ),
            shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 2)

        // Verify removed entity is gone
        XCTAssertNil(result.all.first(where: { $0.entityId == "sensor.old_temp" }))

        // Verify new entity was added
        guard let newLight = result.all.first(where: { $0.entityId == "light.new_light" }) else {
            XCTFail("light.new_light entity couldn't be found in result")
            return
        }
        XCTAssertEqual(newLight.state, "on")
        XCTAssertEqual(newLight.attributes["brightness"] as? Int, 255)
        XCTAssertEqual(newLight.attributes["friendly_name"] as? String, "New Light")

        // Verify changed entity was updated
        guard let changedLight = result.all.first(where: { $0.entityId == "light.bedroom" }) else {
            XCTFail("light.bedroom entity couldn't be found in result")
            return
        }
        XCTAssertEqual(changedLight.state, "off")
        XCTAssertEqual(changedLight.attributes["brightness"] as? Int, 0)

        // Verify preserved attributes from changed entity
        XCTAssertEqual(changedLight.attributes["color_mode"] as? String, "hs")
        XCTAssertEqual(changedLight.attributes["friendly_name"] as? String, "Bedroom Light")
    }

    func testProcessUpdatesAttributeAdditionAndSubtraction() throws {
        // Initial entity with some attributes
        let climateEntity = try HAEntity(
            entityId: "climate.thermostat",
            domain: "climate",
            state: "heat",
            lastChanged: Date(timeIntervalSince1970: 1_767_121_000.0),
            lastUpdated: Date(timeIntervalSince1970: 1_767_121_000.0),
            attributes: [
                "current_temperature": 20.0,
                "target_temperature": 22.0,
                "hvac_mode": "heat",
                "friendly_name": "Thermostat",
            ],
            context: .init(id: "01", userId: nil, parentId: nil)
        )

        // Add auxiliary heat attributes
        let result1 = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "climate.thermostat": {
                                    "+": {
                                        "s": "heat",
                                        "lu": 1767121353.0,
                                        "c": "02",
                                        "a": {
                                            "aux_heat": "on",
                                            "aux_heat_target": 25.0,
                                            "current_temperature": 20.5
                                        }
                                    }
                                }
                            }
                        }
                        """
                    )
                ),
                current: .init(
                    entitiesDictionary: [
                        "climate.thermostat": climateEntity,
                    ]
                )
            ),
            shouldResetEntities: false
        )

        guard let entity1 = result1.all.first else {
            XCTFail("climate.thermostat entity couldn't be found in result")
            return
        }

        // Verify aux heat attributes were added
        XCTAssertEqual(entity1.attributes["aux_heat"] as? String, "on")
        XCTAssertEqual(entity1.attributes["aux_heat_target"] as? Double, 25.0)
        XCTAssertEqual(entity1.attributes["current_temperature"] as? Double, 20.5)

        // Verify original attributes preserved
        XCTAssertEqual(entity1.attributes["target_temperature"] as? Double, 22.0)
        XCTAssertEqual(entity1.attributes["hvac_mode"] as? String, "heat")
        XCTAssertEqual(entity1.attributes["friendly_name"] as? String, "Thermostat")

        // Now subtract the aux heat attributes
        let result2 = try HACacheKeyStates.processUpdates(
            info: .init(
                incoming: .init(
                    data: .init(
                        testJsonString:
                        """
                        {
                            "c": {
                                "climate.thermostat": {
                                    "-": {
                                        "a": ["aux_heat", "aux_heat_target"]
                                    }
                                }
                            }
                        }
                        """
                    )
                ),
                current: result1
            ),
            shouldResetEntities: false
        )

        guard let entity2 = result2.all.first else {
            XCTFail("climate.thermostat entity couldn't be found in result")
            return
        }

        // Verify aux heat attributes were removed
        XCTAssertNil(entity2.attributes["aux_heat"])
        XCTAssertNil(entity2.attributes["aux_heat_target"])

        // Verify everything else still there
        XCTAssertEqual(entity2.attributes["current_temperature"] as? Double, 20.5)
        XCTAssertEqual(entity2.attributes["target_temperature"] as? Double, 22.0)
        XCTAssertEqual(entity2.attributes["hvac_mode"] as? String, "heat")
        XCTAssertEqual(entity2.attributes["friendly_name"] as? String, "Thermostat")
    }
}
