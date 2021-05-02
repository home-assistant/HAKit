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
        XCTAssertNil(webSocket1.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket2.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertEqual(webSocket1.request.value(forHTTPHeaderField: "Host"), "example.com")
        XCTAssertEqual(webSocket1.request.url, url1.appendingPathComponent("api/websocket"))
        XCTAssertEqual(webSocket2.request.url, url2.appendingPathComponent("api/websocket"))
    }

    func testCreationWithEngine() {
        let url = URL(string: "http://example.com/with_engine")!
        let engine1 = FakeEngine()
        let engine2 = FakeEngine()

        let connectionInfo = HAConnectionInfo(url: url, userAgent: nil, engine: engine1)
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(ObjectIdentifier(connectionInfo.engine as AnyObject), ObjectIdentifier(engine1))

        let webSocket = connectionInfo.webSocket()
        XCTAssertNil(webSocket.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "Host"), "example.com")

        webSocket.write(string: "test")
        XCTAssertTrue(engine1.events.contains(.writeString("test")))

        let connectionInfoWithoutEngine = HAConnectionInfo(url: url)
        // just engine difference isn't enough (since we can't tell)
        XCTAssertFalse(connectionInfoWithoutEngine.shouldReplace(webSocket))

        let connectionInfoWithDifferentEngine = HAConnectionInfo(url: url, userAgent: nil, engine: engine2)
        XCTAssertFalse(connectionInfoWithDifferentEngine.shouldReplace(webSocket))
    }

    func testCreationWithUserAgent() {
        let url = URL(string: "http://example.com/with_user_agent")!
        let userAgent = "SomeAgent/1.0"

        let connectionInfo = HAConnectionInfo(url: url, userAgent: userAgent)
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(connectionInfo.userAgent, userAgent)

        let webSocket = connectionInfo.webSocket()
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "User-Agent"), userAgent)
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "Host"), "example.com")
    }

    func testCreationWithNonstandardPort() {
        let url1 = URL(string: "http://example.com:12345/with_porty_host")!
        let url2 = URL(string: "http://example.com:80/with_porty_host")!
        let url3 = URL(string: "https://example.com:443/with_porty_host")!

        let connectionInfo1 = HAConnectionInfo(url: url1)
        let connectionInfo2 = HAConnectionInfo(url: url2)
        let connectionInfo3 = HAConnectionInfo(url: url3)
        XCTAssertEqual(connectionInfo1.url, url1)
        XCTAssertEqual(connectionInfo2.url, url2)
        XCTAssertEqual(connectionInfo3.url, url3)

        let webSocket1 = connectionInfo1.webSocket()
        let webSocket2 = connectionInfo2.webSocket()
        let webSocket3 = connectionInfo3.webSocket()
        XCTAssertNil(webSocket1.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket2.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket3.request.value(forHTTPHeaderField: "User-Agent"))

        XCTAssertEqual(webSocket1.request.value(forHTTPHeaderField: "Host"), "example.com:12345")
        XCTAssertEqual(webSocket2.request.value(forHTTPHeaderField: "Host"), "example.com")
        XCTAssertEqual(webSocket3.request.value(forHTTPHeaderField: "Host"), "example.com")
    }

    func testShouldReplace() {
        let url1 = URL(string: "http://example.com/1")!
        let url2 = URL(string: "http://example.com/2")!
        let engine = FakeEngine()

        let connectionInfo1 = HAConnectionInfo(url: url1, userAgent: nil, engine: engine)
        let connectionInfo2 = HAConnectionInfo(url: url2, userAgent: nil, engine: engine)

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
