@testable import HAWebSocket
import XCTest

internal class HAResponseVoidTests: XCTestCase {
    func testWithDictionary() {
        XCTAssertNoThrow(try HAResponseVoid(data: .dictionary([:])))
    }

    func testWithArray() {
        XCTAssertNoThrow(try HAResponseVoid(data: .array([])))
    }

    func testWithEmpty() {
        XCTAssertNoThrow(try HAResponseVoid(data: .empty))
    }
}
