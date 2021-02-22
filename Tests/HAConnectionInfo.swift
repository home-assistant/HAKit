@testable import HAWebSocket
import XCTest

internal class HAConnectionInfoTests: XCTestCase {
    func testCreation() {
        let url1 = URL(string: "http://example.com")!

        let connectionInfo = HAConnectionInfo(url: url1)
        XCTAssertEqual(connectionInfo.url, url1)
    }
}
