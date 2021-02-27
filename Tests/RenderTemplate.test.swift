@testable import HAWebSocket
import XCTest

internal class RenderTemplateTests: XCTestCase {
    func testRequestWithJustTemplate() {
        let request = HATypedSubscription<HAResponseRenderTemplate>.renderTemplate("{{ test() }}")
        XCTAssertEqual(request.request.type, .renderTemplate)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["template"] as? String, "{{ test() }}")
        XCTAssertNil(request.request.data["timeout"])
        XCTAssertEqual((request.request.data["variables"] as? [String: Any])?.count, 0)
    }

    func testRequestWithExtras() throws {
        let request = HATypedSubscription<HAResponseRenderTemplate>.renderTemplate(
            "{{ test() }}",
            variables: ["a": 1, "b": true],
            timeout: .init(value: 3, unit: .seconds)
        )
        XCTAssertEqual(request.request.type, .renderTemplate)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["template"] as? String, "{{ test() }}")
        XCTAssertEqual(request.request.data["timeout"] as? Double ?? -1, 3, accuracy: 0.01)

        let variables = try XCTUnwrap(request.request.data["variables"] as? [String: Any])
        XCTAssertEqual(variables["a"] as? Int, 1)
        XCTAssertEqual(variables["b"] as? Bool, true)
    }

    func testResponseFull() throws {
        let data = HAData(testJsonString: """
        {
            "result": "string value",
            "listeners": {
                "all": true,
                "entities": [
                    "sun.sun"
                ],
                "domains": [
                    "device_tracker",
                    "automation"
                ],
                "time": true
            }
        }
        """)
        let response = try HAResponseRenderTemplate(data: data)
        XCTAssertEqual(response.result as? String, "string value")
        XCTAssertEqual(response.listeners.all, true)
        XCTAssertEqual(response.listeners.time, true)
        XCTAssertEqual(response.listeners.entities, ["sun.sun"])
        XCTAssertEqual(response.listeners.domains, ["device_tracker", "automation"])
    }

    func testResponseMinimal() throws {
        let data = HAData(testJsonString: """
        {
            "result": true,
            "listeners": {}
        }
        """)
        let response = try HAResponseRenderTemplate(data: data)
        XCTAssertEqual(response.result as? Bool, true)
        XCTAssertEqual(response.listeners.all, false)
        XCTAssertEqual(response.listeners.time, false)
        XCTAssertEqual(response.listeners.entities, [])
        XCTAssertEqual(response.listeners.domains, [])
    }
}
