@testable import HAKit
import XCTest

internal class CallServiceTests: XCTestCase {
    func testRequestWithoutData() {
        let request = HATypedRequest<HAResponseVoid>.callService(
            domain: "some_domain",
            service: "some_service"
        )
        XCTAssertEqual(request.request.type, .callService)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["domain"] as? String, "some_domain")
        XCTAssertEqual(request.request.data["service"] as? String, "some_service")
        XCTAssertEqual((request.request.data["service_data"] as? [String: Any])?.count, 0)
    }

    func testRequestWithData() {
        let request = HATypedRequest<HAResponseVoid>.callService(
            domain: "some_domain",
            service: "some_service",
            data: [
                "key1": 1,
                "key2": true,
                "key3": ["yes", "or", "no"],
            ]
        )
        XCTAssertEqual(request.request.type, .callService)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["domain"] as? String, "some_domain")
        XCTAssertEqual(request.request.data["service"] as? String, "some_service")

        guard let data = request.request.data["service_data"] as? [String: Any] else {
            XCTFail("service data was not provided when we expected it to be")
            return
        }

        XCTAssertEqual(data["key1"] as? Int, 1)
        XCTAssertEqual(data["key2"] as? Bool, true)
        XCTAssertEqual(data["key3"] as? [String], ["yes", "or", "no"])
    }

    func testResponse() {
        // response is type void, no need to test
    }
}
