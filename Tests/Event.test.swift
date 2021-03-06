@testable import HAKit
import XCTest

internal class EventTests: XCTestCase {
    func testRequestAll() {
        let request = HATypedSubscription<HAResponseEvent>.events(.all)
        XCTAssertEqual(request.request.type, .subscribeEvents)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data.count, 0)
    }

    func testRequestSpecific() {
        let request = HATypedSubscription<HAResponseEvent>.events("test")
        XCTAssertEqual(request.request.type, .subscribeEvents)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["event_type"] as? String, "test")
    }

    func testUnsubscribe() {
        let request = HATypedRequest<HAResponseVoid>.unsubscribe(33)
        XCTAssertEqual(request.request.type, .unsubscribeEvents)
        XCTAssertEqual(request.request.shouldRetry, false)
        XCTAssertEqual(request.request.data["subscription"] as? Int, 33)
    }

    func testResponseFull() throws {
        let data = HAData(testJsonString: """
        {
            "event_type": "state_changed",
            "data": {"test": true},
            "origin": "LOCAL",
            "time_fired": "2021-02-24T04:31:10.045916+00:00",
            "context": {
                "id": "ebc9bf93dd90efc0770f1dc49096788f",
                "parent_id": "9e47ec85012dc304ad412ffa78c54c196ff156a1",
                "user_id": "76ce52a813c44fdf80ee36f926d62328"
            }
        }
        """)
        let response = try HAResponseEvent(data: data)
        XCTAssertEqual(response.type, .stateChanged)
        XCTAssertEqual(response.data["test"] as? Bool, true)
        XCTAssertEqual(response.origin, .local)
        XCTAssertEqual(response.context.id, "ebc9bf93dd90efc0770f1dc49096788f")
        XCTAssertEqual(response.context.parentId, "9e47ec85012dc304ad412ffa78c54c196ff156a1")
        XCTAssertEqual(response.context.userId, "76ce52a813c44fdf80ee36f926d62328")
    }

    func testResponseMinimal() throws {
        let data = HAData(testJsonString: """
        {
            "event_type": "state_changed",
            "origin": "REMOTE",
            "time_fired": "2021-02-24T04:31:10.045916+00:00",
            "context": {
                "id": "ebc9bf93dd90efc0770f1dc49096788f"
            }
        }
        """)
        let response = try HAResponseEvent(data: data)
        XCTAssertEqual(response.type, .stateChanged)
        XCTAssertEqual(response.data.isEmpty, true)
        XCTAssertEqual(response.origin, .remote)
        XCTAssertEqual(response.context.id, "ebc9bf93dd90efc0770f1dc49096788f")
        XCTAssertEqual(response.context.parentId, nil)
        XCTAssertEqual(response.context.userId, nil)
    }
}
