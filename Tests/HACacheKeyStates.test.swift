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
                    entities: []
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
                    entities: [
                        existentEntity,
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
                    entities: [
                        existentEntity,
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
                    entities: []
                )
            ), shouldResetEntities: false
        )

        XCTAssertEqual(result.all.count, 0)
        wait(for: [expectation])
    }
}
