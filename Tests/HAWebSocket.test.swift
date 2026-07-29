@testable import HAKit
import XCTest

internal class HAWebSocketTests: XCTestCase {
    private final class RecordingDelegate: HAWebSocketDelegate {
        var onEvent: ((HAWebSocketEvent, Bool) -> Void)?
        func didReceive(event: HAWebSocketEvent) {
            onEvent?(event, Thread.isMainThread)
        }
    }

    /// The engine delivers events on its background delegate queue, but `HAConnection` mutates
    /// main-confined state and asserts `Thread.isMainThread` on disconnect, so `HAWebSocket` must hop
    /// engine events to the main queue before forwarding them.
    func testForwardsEngineEventsOnMainQueue() throws {
        let engine = FakeEngine()
        let request = try URLRequest(url: XCTUnwrap(URL(string: "wss://example.com/api/websocket")))
        let webSocket = HAWebSocket(request: request, engine: engine)

        let delegate = RecordingDelegate()
        webSocket.delegate = delegate

        let received = expectation(description: "event delivered on the main queue")
        delegate.onEvent = { event, isMainThread in
            XCTAssertEqual(event, .text("hello"))
            XCTAssertTrue(isMainThread, "engine events must be delivered on the main queue")
            received.fulfill()
        }

        // Simulate the engine delivering an event from off the main queue.
        DispatchQueue.global().async {
            engine.delegate?.didReceive(event: .text("hello"))
        }

        wait(for: [received], timeout: 5)
    }

    func testEventEquatable() {
        XCTAssertEqual(HAWebSocketEvent.peerClosed, .peerClosed)
        XCTAssertEqual(HAWebSocketEvent.text("a"), .text("a"))
        // Mismatched cases are never equal (exercises the default comparison branch).
        XCTAssertNotEqual(HAWebSocketEvent.peerClosed, .cancelled)
        XCTAssertNotEqual(HAWebSocketEvent.text("a"), .binary(Data()))
    }

    func testWriteForwardsToEngine() throws {
        let engine = FakeEngine()
        let request = try URLRequest(url: XCTUnwrap(URL(string: "wss://example.com/api/websocket")))
        let webSocket = HAWebSocket(request: request, engine: engine)

        webSocket.write(string: "text")
        webSocket.write(data: Data("binary".utf8))

        XCTAssertTrue(engine.events.contains(.writeString("text")))
        XCTAssertTrue(engine.events.contains(.writeData(Data("binary".utf8), opcode: .binaryFrame)))
    }
}
