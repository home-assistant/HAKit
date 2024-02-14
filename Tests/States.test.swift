@testable import HAKit
import XCTest

internal class StatesTests: XCTestCase {
    func testStateChangedRequest() {
        let request = HATypedSubscription<HAResponseEventStateChanged>.stateChanged()
        XCTAssertEqual(request.request.type, .subscribeEvents)
        XCTAssertEqual(request.request.data["event_type"] as? String, HAEventType.stateChanged.rawValue)
    }

    func testStateChangedResponseFull() throws {
        let data = HAData(testJsonString: """
        {
            "event_type": "state_changed",
            "data": {
                "entity_id": "input_select.muffin",
                "old_state": {
                    "entity_id": "input_select.muffin",
                    "state": "three",
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
                    "last_changed": "2021-02-23T05:55:17.008448+00:00",
                    "last_updated": "2021-02-23T05:55:17.008448+00:00",
                    "context": {
                        "id": "81c2755244fc6356fa52bffa76343f03",
                        "parent_id": null,
                        "user_id": "76ce52a813c44fdf80ee36f926d62328"
                    }
                },
                "new_state": {
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
                    "last_changed": "2021-02-24T04:31:10.045916+00:00",
                    "last_updated": "2021-02-24T04:31:10.045916+00:00",
                    "context": {
                        "id": "ebc9bf93dd90efc0770f1dc49096788f",
                        "parent_id": null,
                        "user_id": "76ce52a813c44fdf80ee36f926d62328"
                    }
                }
            },
            "origin": "LOCAL",
            "time_fired": "2021-02-24T04:31:10.045916+00:00",
            "context": {
                "id": "ebc9bf93dd90efc0770f1dc49096788f",
                "parent_id": null,
                "user_id": "76ce52a813c44fdf80ee36f926d62328"
            }
        }
        """)
        let response = try HAResponseEventStateChanged(data: data)
        XCTAssertEqual(response.event.type, .stateChanged)
        XCTAssertEqual(response.entityId, "input_select.muffin")
        XCTAssertEqual(response.oldState?.entityId, "input_select.muffin")
        XCTAssertEqual(response.newState?.entityId, "input_select.muffin")
    }

    func testStateChangedResponseNoOld() throws {
        let data = HAData(testJsonString: """
        {
            "event_type": "state_changed",
            "data": {
                "entity_id": "input_select.muffin",
                "new_state": {
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
                    "last_changed": "2021-02-24T04:31:10.045916+00:00",
                    "last_updated": "2021-02-24T04:31:10.045916+00:00",
                    "context": {
                        "id": "ebc9bf93dd90efc0770f1dc49096788f",
                        "parent_id": null,
                        "user_id": "76ce52a813c44fdf80ee36f926d62328"
                    }
                }
            },
            "origin": "LOCAL",
            "time_fired": "2021-02-24T04:31:10.045916+00:00",
            "context": {
                "id": "ebc9bf93dd90efc0770f1dc49096788f",
                "parent_id": null,
                "user_id": "76ce52a813c44fdf80ee36f926d62328"
            }
        }
        """)
        let response = try HAResponseEventStateChanged(data: data)
        XCTAssertEqual(response.event.type, .stateChanged)
        XCTAssertEqual(response.entityId, "input_select.muffin")
        XCTAssertNil(response.oldState)
        XCTAssertEqual(response.newState?.entityId, "input_select.muffin")
    }

    func testStateChangedResponseNoOldOrNew() throws {
        let data = HAData(testJsonString: """
        {
            "event_type": "state_changed",
            "data": {
                "entity_id": "input_select.muffin"
            },
            "origin": "LOCAL",
            "time_fired": "2021-02-24T04:31:10.045916+00:00",
            "context": {
                "id": "ebc9bf93dd90efc0770f1dc49096788f",
                "parent_id": null,
                "user_id": "76ce52a813c44fdf80ee36f926d62328"
            }
        }
        """)
        let response = try HAResponseEventStateChanged(data: data)
        XCTAssertEqual(response.event.type, .stateChanged)
        XCTAssertEqual(response.entityId, "input_select.muffin")
        XCTAssertNil(response.oldState)
        XCTAssertNil(response.newState)
    }
}
