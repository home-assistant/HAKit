@testable import HAKit
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
        controller.workQueue = DispatchQueue(label: "unit-test-work-queue")
    }

    func testInitialPhase() {
        XCTAssertEqual(controller.phase, .disconnected(error: nil, forReset: true))
    }

    func testInitialErrored() {
        enum FakeError: Error {
            case error
        }

        fireErrored(error: nil)
        fireErrored(error: FakeError.error)
    }

    func testConnectedThenDisconnected() {
        fireConnected()
        fireDisconnected()
    }

    func testConnectedThenReset() {
        fireConnected()
        controller.reset()
        XCTAssertEqual(controller.phase, .disconnected(error: nil, forReset: true))
        XCTAssertEqual(delegate.lastPhase, .disconnected(error: nil, forReset: true))
    }

    func testConnectedThenCancelled() {
        fireConnected()
        fireCancelled()
    }

    func testConnectedThenErrored() {
        enum FakeError: Error {
            case error
        }

        fireConnected()
        fireErrored(error: FakeError.error)
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
            waitForCallback()
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
        try fireText(
            from: HAWebSocketResponseFixture.responseError,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
        fireDisconnected()
    }

    func testInvalidText() throws {
        fireConnected()

        controller.didReceive(event: .text("{"))
        controller.didReceive(event: .text("[true]"))

        waitForCallback()

        XCTAssertNil(delegate.lastReceived)
    }

    func testPong() throws {
        fireConnected()

        let commandPhase = HAResponseControllerPhase.command(version: "2021.3.0.dev0")

        try fireText(
            from: HAWebSocketResponseFixture.authOK,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
        try fireText(
            from: HAWebSocketResponseFixture.responsePong,
            expectingResponse: true,
            expectingPhase: commandPhase
        )
    }

    func testRestResponseFailure() throws {
        enum FakeError: Error {
            case error
        }
        controller.didReceive(for: 456, response: .failure(FakeError.error))
        XCTAssertEqual(
            delegate.lastReceived,
            .result(identifier: 456, result: .failure(.underlying(FakeError.error as NSError)))
        )
    }

    func testRestResponse4xx() throws {
        let response =
            try XCTUnwrap(HTTPURLResponse(
                url: URL(string: "http://example.com")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
        let dataString = "error msg"
        controller.didReceive(for: 888, response: .success((response, dataString.data(using: .utf8))))
        XCTAssertEqual(
            delegate.lastReceived,
            .result(identifier: 888, result: .failure(.external(.init(code: "401", message: dataString))))
        )

        controller.didReceive(for: 888, response: .success((response, nil)))
        XCTAssertEqual(
            delegate.lastReceived,
            .result(
                identifier: 888,
                result: .failure(.external(.init(code: "401", message: "Unacceptable status code")))
            )
        )
    }

    func testRestResponseSuccess() throws {
        let responseJSON =
            try XCTUnwrap(HTTPURLResponse(
                url: URL(string: "http://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
        let responseString =
            try XCTUnwrap(HTTPURLResponse(
                url: URL(string: "http://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/octet-stream"]
            ))
        let responseNoHeader =
            try XCTUnwrap(HTTPURLResponse(
                url: URL(string: "http://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))

        controller.didReceive(for: 1, response: .success((responseJSON, nil)))
        waitForCallback()
        XCTAssertEqual(delegate.lastReceived, .result(identifier: 1, result: .success(.empty)))

        delegate.lastReceived = nil

        let resultDictionary = ["test": true]
        controller.didReceive(
            for: 2,
            response: .success((
                responseJSON,
                try JSONSerialization.data(withJSONObject: resultDictionary, options: [])
            ))
        )
        waitForCallback()
        XCTAssertEqual(delegate.lastReceived, .result(identifier: 2, result: .success(.dictionary(resultDictionary))))

        delegate.lastReceived = nil

        let invalidJson = "{".data(using: .utf8)
        controller.didReceive(for: 3, response: .success((responseJSON, invalidJson)))
        waitForCallback()

        switch delegate.lastReceived {
        case .result(identifier: 3, result: .failure(.underlying(_))):
            // pass
            break
        default:
            XCTFail("expected error response")
        }

        delegate.lastReceived = nil

        controller.didReceive(for: 4, response: .success((responseString, invalidJson)))
        waitForCallback()
        XCTAssertEqual(delegate.lastReceived, .result(identifier: 4, result: .success(.primitive("{"))))

        delegate.lastReceived = nil

        controller.didReceive(
            for: 2,
            response: .success((
                responseNoHeader,
                try JSONSerialization.data(withJSONObject: resultDictionary, options: [])
            ))
        )
        waitForCallback()
        XCTAssertEqual(delegate.lastReceived, .result(identifier: 2, result: .success(.dictionary(resultDictionary))))
    }
}

private extension HAResponseControllerTests {
    func waitForCallback() {
        let expectation = self.expectation(description: "queueing")
        controller.workQueue.sync {
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }

    func fireConnected(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .connected([:]))
        waitForCallback()
        XCTAssertEqual(controller.phase, .auth, file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .auth, file: file, line: line)
    }

    func fireDisconnected(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .disconnected("debug", 0))
        waitForCallback()
        XCTAssertEqual(controller.phase, .disconnected(error: nil, forReset: false), file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected(error: nil, forReset: false), file: file, line: line)
    }

    func fireCancelled(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .cancelled)
        waitForCallback()
        XCTAssertEqual(controller.phase, .disconnected(error: nil, forReset: false), file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected(error: nil, forReset: false), file: file, line: line)
    }

    func fireErrored(
        error: Error?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        controller.didReceive(event: .error(error))
        waitForCallback()
        XCTAssertEqual(controller.phase, .disconnected(error: error, forReset: false), file: file, line: line)
        XCTAssertEqual(delegate.lastPhase, .disconnected(error: error, forReset: false), file: file, line: line)
    }

    func fireText(
        from object: [String: Any],
        expectingResponse: Bool,
        expectingPhase: HAResponseControllerPhase
    ) throws {
        let text =
            try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: object, options: []), encoding: .utf8))

        controller.didReceive(event: .text(text))

        waitForCallback()

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
