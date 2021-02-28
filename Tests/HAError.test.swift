@testable import HAWebSocket
import XCTest

internal class HAErrorTests: XCTestCase {
    func testLocalizedDescription() {
        let error1 = HAError.internal(debugDescription: "msg1")
        XCTAssertEqual(error1.localizedDescription, "msg1")

        let error2 = HAError.external(.init(code: "code", message: "msg2"))
        XCTAssertEqual(error2.localizedDescription, "msg2")
    }

    func testExternalErrorInitWithBad() {
        XCTAssertEqual(HAError.ExternalError(true), .invalid)
        XCTAssertEqual(HAError.ExternalError([:]), .invalid)
        XCTAssertEqual(HAError.ExternalError(["code": nil, "message": "message"]), .invalid)
    }

    func testExternalErrorInitWithGood() {
        let error1 = HAError.ExternalError(["code": "code1", "message": "msg"])
        XCTAssertEqual(error1.code, "code1")
        XCTAssertEqual(error1.message, "msg")

        let error2 = HAError.ExternalError(["code": "code2", "message": "msg2"])
        XCTAssertEqual(error2.code, "code2")
        XCTAssertEqual(error2.message, "msg2")
    }
}
