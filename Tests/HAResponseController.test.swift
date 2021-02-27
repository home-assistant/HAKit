@testable import HAWebSocket
import Starscream
import XCTest

internal class HAResponseControllerTests: XCTestCase {
    private var controller: HAResponseControllerImpl!
    // swiftlint:disable:next weak_delegate
    private var delegate: FakeHAResponseControllerDelegate!

    override func setUp() {
        super.setUp()

        delegate = FakeHAResponseControllerDelegate()
        controller = HAResponseControllerImpl()
        controller.delegate = delegate
    }

    func testInitialPhase() {
        XCTAssertEqual(controller.phase, .disconnected)
    }

    func testInitialErrored() {
        fireErrored()
    }

    func testConnectedThenDisconnected() {
        fireConnected()
        fireDisconnected()
    }

    func testConnectedThenReset() {
        fireConnected()
        controller.reset()
        XCTAssertEqual(controller.phase, .disconnected)
        XCTAssertEqual(delegate.lastPhase, .disconnected)
    }

    func testConnectedThenCancelled() {
        fireConnected()
        fireCancelled()
    }

    func testConnectedThenErrored() {
        fireConnected()
        fireErrored()
    }

    func testIgnoredEvents() {
        fireConnected()

        for event: Starscream.WebSocketEvent in [
            .binary(.init(count: 100)),
            .ping(nil),
            .pong(nil),
            .reconnectSuggested(true),
            .viabilityChanged(true),
        ] {
            controller.didReceive(event: event)
            XCTAssertEqual(delegate.lastPhase, .auth)
            XCTAssertNil(delegate.lastReceived)
        }
    }

    func testAuthFlow() throws {
        fireConnected()
        try fireText(
            from: HAWebSocketResponseFixture.authRequired,
            expectingResponse: true,
            expectingPhase: .auth
        )

        let commandPhase = HAResponseControllerPhase.command(version: "2021.3.0.dev0")

        try fireText(
            from: HAWebSocketResponseFixture.authOK,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
        try fireText(
            from: HAWebSocketResponseFixture.responseEvent,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
        try fireText(
            from: HAWebSocketResponseFixture.responseDictionaryResult,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
        fireDisconnected()
    }

    func testInvalidText() throws {
        fireConnected()
        try fireText(
            from: [:],
            expectingResponse: false,
            expectingPhase: .auth
        )
        XCTAssertNil(delegate.lastReceived)
    }
}

private extension HAResponseControllerTests {
    func fireConnected(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .connected([:]))
        XCTAssertEqual(controller.phase, .auth, file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .auth, file: file, line: line)
    }

    func fireDisconnected(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .disconnected("debug", 0))
        XCTAssertEqual(controller.phase, .disconnected, file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected, file: file, line: line)
    }

    func fireCancelled(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .cancelled)
        XCTAssertEqual(controller.phase, .disconnected, file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected, file: file, line: line)
    }

    func fireErrored(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .error(nil))
        XCTAssertEqual(controller.phase, .disconnected, file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected, file: file, line: line)
    }

    func fireText(
        from object: [String: Any],
        expectingResponse: Bool,
        expectingPhase: HAResponseControllerPhase
    ) throws {
        let text =
            try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: object, options: []), encoding: .utf8))

        controller.didReceive(event: .text(text))

        if expectingResponse {
            let response = try HAWebSocketResponse(dictionary: object)
            XCTAssertEqual(delegate.lastReceived, response)
        }

        XCTAssertEqual(delegate.lastPhase, expectingPhase)
    }
}

private class FakeHAResponseControllerDelegate: HAResponseControllerDelegate {
    var lastPhase: HAResponseControllerPhase?

    func responseController(
        _ controller: HAResponseController,
        didTransitionTo phase: HAResponseControllerPhase
    ) {
        lastPhase = phase
    }

    var lastReceived: HAWebSocketResponse?

    func responseController(
        _ controller: HAResponseController,
        didReceive response: HAWebSocketResponse
    ) {
        lastReceived = response
    }
}
