@testable import HAKit
import Starscream
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

        let webSocket1 = connectionInfo1.webSocket()
        let webSocket2 = connectionInfo3.webSocket()
        XCTAssertEqual(webSocket1.request.url, url1.appendingPathComponent("api/websocket"))
        XCTAssertEqual(webSocket2.request.url, url2.appendingPathComponent("api/websocket"))
    }

    func testCreationWithEngine() {
        let url = URL(string: "http://example.com/with_engine")!
        let engine1 = FakeEngine()
        let engine2 = FakeEngine()

        let connectionInfo = HAConnectionInfo(url: url, engine: engine1)
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(ObjectIdentifier(connectionInfo.engine as AnyObject), ObjectIdentifier(engine1))

        let webSocket = connectionInfo.webSocket()
        webSocket.write(string: "test")
        XCTAssertTrue(engine1.events.contains(.writeString("test")))

        let connectionInfoWithoutEngine = HAConnectionInfo(url: url)
        // just engine difference isn't enough (since we can't tell)
        XCTAssertFalse(connectionInfoWithoutEngine.shouldReplace(webSocket))

        let connectionInfoWithDifferentEngine = HAConnectionInfo(url: url, engine: engine2)
        XCTAssertFalse(connectionInfoWithDifferentEngine.shouldReplace(webSocket))
    }

    func testShouldReplace() {
        let url1 = URL(string: "http://example.com/1")!
        let url2 = URL(string: "http://example.com/2")!
        let engine = FakeEngine()

        let connectionInfo1 = HAConnectionInfo(url: url1, engine: engine)
        let connectionInfo2 = HAConnectionInfo(url: url2, engine: engine)

        let webSocket1 = connectionInfo1.webSocket()
        XCTAssertFalse(connectionInfo1.shouldReplace(webSocket1))
        XCTAssertTrue(connectionInfo2.shouldReplace(webSocket1))
    }

    func testSanitize() throws {
        let expected = try XCTUnwrap(URL(string: "http://example.com"))

        for invalid in [
            "http://example.com",
            "http://example.com/",
            "http://example.com/////",
            "http://example.com/api",
            "http://example.com/api/",
            "http://example.com/api/websocket",
            "http://example.com/api/websocket/",
        ] {
            let url = try XCTUnwrap(URL(string: invalid))
            let connectionInfo = HAConnectionInfo(url: url)
            XCTAssertEqual(connectionInfo.url, expected)
        }
    }

    func testInvalidURLComponentsURL() throws {
        // example of valid URL invalid URLComponents - https://stackoverflow.com/questions/55609012
        let url = try XCTUnwrap(URL(string: "a://@@/api/websocket"))
        let connectionInfo = HAConnectionInfo(url: url)
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(connectionInfo.webSocket().request.url, url.appendingPathComponent("api/websocket"))
    }
}
