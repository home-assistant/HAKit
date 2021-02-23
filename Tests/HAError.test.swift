@testable import HAWebSocket
import XCTest

internal class HAErrorTests: XCTestCase {
    func testExternalErrorInitWithBad() {
        XCTAssertEqual(HAError.ExternalError(true), .invalid)
        XCTAssertEqual(HAError.ExternalError([:]), .invalid)
        XCTAssertEqual(HAError.ExternalError(["code": "moo", "message": "message"]), .invalid)
    }

    func testExternalErrorInitWithGood() {
        let error1 = HAError.ExternalError(["code": 3, "message": "msg"])
        XCTAssertEqual(error1.code, 3)
        XCTAssertEqual(error1.message, "msg")

        let error2 = HAError.ExternalError(["code": -100, "message": "msg2"])
        XCTAssertEqual(error2.code, -100)
        XCTAssertEqual(error2.message, "msg2")
    }
}
