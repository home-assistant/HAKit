@testable import HAWebSocket
import XCTest

internal class HAConnectionInfoTests: XCTestCase {
    func testCreation() {
        let url1 = URL(string: "http://example.com")!
        let url2 = URL(string: "http://example.com/2")!

        let connectionInfo1 = HAConnectionInfo(url: url1)
        XCTAssertEqual(connectionInfo1.url, url1)
        XCTAssertEqual(connectionInfo1, connectionInfo1)

        let connectionInfo2 = HAConnectionInfo(url: url1)
        XCTAssertEqual(connectionInfo1, connectionInfo2)

        let connectionInfo3 = HAConnectionInfo(url: url2)
        XCTAssertEqual(connectionInfo3, connectionInfo3)

        XCTAssertNotEqual(connectionInfo1, connectionInfo3)
        XCTAssertNotEqual(connectionInfo2, connectionInfo3)
    }
}
