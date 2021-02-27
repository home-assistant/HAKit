@testable import HAWebSocket
import Starscream
import XCTest

internal class HAConnectionImplTests: XCTestCase {
    private var url: URL!
    private var engine: FakeEngine!
    private var pendingFetchAccessTokens: [(Result<String, Error>) -> Void]!
    private var connection: HAConnectionImpl!
    private var callbackQueue: DispatchQueue!
    private var queueSpecific = DispatchSpecificKey<Bool>()
    private var requestController: FakeHARequestController!
    private var responseController: FakeHAResponseController!
    // swiftlint:disable:next weak_delegate
    private var delegate: FakeHAConnectionDelegate!

    private var isOnCallbackQueue: Bool {
        DispatchQueue.getSpecific(key: queueSpecific) == true
    }

    override func setUp() {
        super.setUp()

        requestController = FakeHARequestController()
        responseController = FakeHAResponseController()
        delegate = FakeHAConnectionDelegate()

        queueSpecific = .init()
        callbackQueue = DispatchQueue(label: "test-callback-queue")
        callbackQueue.setSpecific(key: queueSpecific, value: true)

        pendingFetchAccessTokens = []
        url = URL(string: "http://example.com/default")!
        engine = FakeEngine()
        connection = .init(
            configuration: .init(connectionInfo: { [weak self] in
                if let url = self?.url, let engine = self?.engine {
                    return .init(url: url, engine: engine)
                } else {
                    XCTFail("invoked after deallocated")
                    return .init(url: URL(string: "http://example.com/invalid")!)
                }
            }, fetchAuthToken: { [weak self] handler in
                self?.pendingFetchAccessTokens.append(handler)
            }),
            requestController: requestController,
            responseController: responseController
        )
        connection.callbackQueue = callbackQueue
        connection.delegate = delegate
    }

    private func assertSent(
        identifier: HARequestIdentifier?,
        request: HARequest,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let lastEvent = try XCTUnwrap(engine.events.last)

        switch lastEvent {
        case let .writeString(string):
            let jsonRep = try XCTUnwrap(JSONSerialization.jsonObject(
                with: XCTUnwrap(string.data(using: .utf8)),
                options: []
            ) as? [String: Any])

            if let identifier = identifier {
                XCTAssertEqual(jsonRep["id"] as? Int, identifier.rawValue)
            }

            XCTAssertEqual(jsonRep["type"] as? String, request.type.rawValue)

            var copy = jsonRep
            copy["id"] = nil
            copy["type"] = nil
            let copyData = try JSONSerialization.data(withJSONObject: copy, options: [.sortedKeys])
            let requestData = try JSONSerialization.data(withJSONObject: request.data, options: [.sortedKeys])
            XCTAssertEqual(copyData, requestData)
        default:
            XCTFail("did not write a string for the last event")
        }
    }

    func testCreation() {
        XCTAssertTrue(engine.events.isEmpty)
        XCTAssertEqual(connection.state, .disconnected(reason: .initial))
    }

    func testConnectionConnect() throws {
        connection.connect()
        let expectedURL = HAConnectionInfo(url: url).webSocketURL
        XCTAssertTrue(engine.events.contains(where: { event in
            if case let .start(request) = event {
                return request.url == expectedURL
            } else {
                return false
            }
        }))

        // connect a second time, it shouldn't disconnect but it can call
        // connect again np
        connection.connect()
        XCTAssertEqual(engine.events.count, 2)
        XCTAssertFalse(engine.events.contains(where: { event in
            if case .stop = event {
                return true
            } else {
                return false
            }
        }))

        XCTAssertTrue(responseController.wasReset)
        responseController.wasReset = false

        let oldEngine = try XCTUnwrap(engine)
        engine = FakeEngine()
        url = url.appendingPathComponent("hi")
        let newExpectedURL = HAConnectionInfo(url: url).webSocketURL

        connection.connect()
        XCTAssertTrue(oldEngine.events.contains(.stop(CloseCode.goingAway.rawValue)))
        XCTAssertTrue(engine.events.contains(where: { event in
            if case let .start(request) = event {
                return request.url == newExpectedURL
            } else {
                return false
            }
        }))

        XCTAssertTrue(responseController.wasReset)
    }

    func testDisconnect() {
        connection.connect()

        engine.events.removeAll()

        connection.disconnect()
        XCTAssertTrue(engine.events.contains(.stop(CloseCode.goingAway.rawValue)))
    }

    func testShouldSendRequestsDuringCommandPhase() {
        responseController.phase = .disconnected
        XCTAssertFalse(connection.requestControllerShouldSendRequests(requestController))

        responseController.phase = .auth
        XCTAssertFalse(connection.requestControllerShouldSendRequests(requestController))

        responseController.phase = .command(version: "")
        XCTAssertTrue(connection.requestControllerShouldSendRequests(requestController))
    }

    func testDidPrepareRequest() throws {
        connection.connect()

        let identifier: HARequestIdentifier = 123
        let request = HARequest(type: "test_type", data: ["test": true])
        connection.requestController(requestController, didPrepareRequest: request, with: identifier)
        try assertSent(identifier: identifier, request: request)
    }

    func testConnectedSendsAuthTokenGetSucceeds() throws {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .auth
        connection.responseController(responseController, didTransitionTo: .auth)
        XCTAssertEqual(delegate.states, [.connecting])

        XCTAssertTrue(engine.events.isEmpty)

        try XCTUnwrap(pendingFetchAccessTokens.last)(.success("token!"))
        try assertSent(identifier: nil, request: .init(
            type: .auth,
            data: ["access_token": "token!"]
        ))
    }

    func testConnectedSendsAuthTokenGetFails() throws {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .auth
        connection.responseController(responseController, didTransitionTo: .auth)
        XCTAssertEqual(delegate.states, [.connecting])

        XCTAssertTrue(engine.events.isEmpty)

        enum TestError: Error {
            case any
        }

        try XCTUnwrap(pendingFetchAccessTokens.last)(.failure(TestError.any))
        XCTAssertTrue(engine.events.contains(.stop(CloseCode.goingAway.rawValue)))

        let last = try XCTUnwrap(delegate.states.last)
        switch last {
        case .disconnected(reason: _):
            // TODO: test reconnect or that it's temporary
            break
        default:
            XCTFail("last state should have been disconnecting, got \(last)")
        }
    }

    func testCommandPreparesRequests() {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .command(version: "123")
        connection.responseController(responseController, didTransitionTo: .command(version: "123"))
        XCTAssertEqual(delegate.states, [.ready(version: "123")])

        XCTAssertTrue(requestController.didPrepare)
    }

    func testDisconnectResetsActive() {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .disconnected
        connection.responseController(responseController, didTransitionTo: .disconnected)
        XCTAssertEqual(delegate.states, [.disconnected(reason: .initial)])

        XCTAssertTrue(requestController.didResetActive)
    }

    func testReceivedEventForwardedToResponseController() throws {
        for event: WebSocketEvent in [
            .binary(Data()),
            .cancelled,
            .connected(["a": "b"]),
            .disconnected("a", 0xB),
            .error(NSError(domain: "a", code: 1, userInfo: ["b": true])),
            .ping(Data()),
            .pong(Data()),
            .reconnectSuggested(true),
            .text("abc"),
            .viabilityChanged(true),
        ] {
            responseController.received.removeAll()
            connection.didReceive(event: event, client: connection.configuration.connectionInfo().webSocket())
            XCTAssertEqual(try XCTUnwrap(responseController.received.last), event)
        }
    }

    func testResponseEventAuth() {
        connection.responseController(responseController, didReceive: .auth(.required))
        connection.responseController(responseController, didReceive: .auth(.ok(version: "")))
        connection.responseController(responseController, didReceive: .auth(.invalid))
        XCTAssertTrue(engine.events.isEmpty)
        XCTAssertTrue(responseController.received.isEmpty)
        XCTAssertTrue(delegate.states.isEmpty)
        XCTAssertFalse(requestController.didPrepare)
        XCTAssertFalse(requestController.didResetActive)
    }

    func testResponseResultNoSingleOrSubscription() {
        connection.responseController(
            responseController,
            didReceive: .result(identifier: 383, result: .success(.empty))
        )
    }

    func testResponseResultSingle() {
        let expectedResult: Result<HAData, HAError> = .success(.dictionary(["yep": true]))

        let expectation = self.expectation(description: "invoked completion")

        let invocation: HARequestInvocationSingle = .init(
            request: .init(type: "type", data: [:]),
            completion: { result in
                XCTAssertTrue(self.isOnCallbackQueue)
                XCTAssertEqual(result, expectedResult)

                expectation.fulfill()
            }
        )
        requestController.singles[1987] = invocation

        connection.responseController(
            responseController,
            didReceive: .result(identifier: 1987, result: expectedResult)
        )

        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(requestController.cleared.contains(invocation))
    }

    func testResponseResultSubscription() {
        let expectedResult: Result<HAData, HAError> = .success(.dictionary(["yep": true]))

        let expectation = self.expectation(description: "invoked completion")

        requestController.subscriptions[1987] = .init(
            request: .init(type: "type", data: [:]),
            initiated: { result in
                XCTAssertTrue(self.isOnCallbackQueue)
                XCTAssertEqual(result, expectedResult)

                expectation.fulfill()
            },
            handler: { _, _ in
                XCTFail("didn't expect handler to be invoked")
            }
        )

        connection.responseController(
            responseController,
            didReceive: .result(identifier: 1987, result: expectedResult)
        )

        waitForExpectations(timeout: 10.0)
    }

    func testResponseEventExists() {
        let expectedData: HAData = .dictionary(["test": true])
        let expectation = self.expectation(description: "handler invoked")
        expectation.expectedFulfillmentCount = 2

        var lastToken: HACancellable?

        let invocation = HARequestInvocationSubscription(
            request: .init(type: "type", data: [:]),
            initiated: { _ in
                XCTFail("didn't expect initiated to be invoked")
            },
            handler: { token, data in
                XCTAssertTrue(self.isOnCallbackQueue)
                XCTAssertEqual(data, expectedData)

                lastToken = token

                expectation.fulfill()
            }
        )
        requestController.subscriptions[123] = invocation

        connection.responseController(
            responseController,
            didReceive: .event(identifier: 123, data: expectedData)
        )

        connection.responseController(
            responseController,
            didReceive: .event(identifier: 123, data: expectedData)
        )

        waitForExpectations(timeout: 10.0)

        lastToken?.cancel()
        XCTAssertTrue(requestController.cancelled.contains(invocation))
    }

    func testResponseEventDoesntExist() {
        connection.responseController(
            responseController,
            didReceive: .event(identifier: 4, data: .empty)
        )

        let added = requestController.added.first(where: { added in
            added.request.type == .unsubscribeEvents
                && added.request.data["subscription"] as? Int == 4
                && added.request.shouldRetry == false
        }) as? HARequestInvocationSingle
        XCTAssertNotNil(added)

        // just validating the completion handler doesn't cause issues when fired
        added?.resolve(.success(.empty))
    }

    func testPlainSendCancelled() throws {
        let token = connection.send(.init(type: "test1", data: ["data": true]), completion: { result in
            XCTFail("should not have invoked completion when cancelled")
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "test1" && invoc.request.data["data"] as? Bool == true
        }))

        token.cancel()
        XCTAssertTrue(requestController.cancelled.contains(added))
    }

    func testPlainSendSentSuccessful() throws {
        let expectation = self.expectation(description: "completion")
        responseController.phase = .command(version: "a")
        _ = connection.send(.init(type: "happy", data: ["data": true]), completion: { result in
            XCTAssertEqual(result, .success(.dictionary(["still_happy": true])))
            expectation.fulfill()
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "happy" && invoc.request.data["data"] as? Bool == true
        }) as? HARequestInvocationSingle)

        // we test the "when something is added" flow elsewhere; skip end-to-end and invoke directly
        added.resolve(.success(.dictionary(["still_happy": true])))
        waitForExpectations(timeout: 10.0)
    }

    func testPlainSendSentFailure() throws {
        let expectation = self.expectation(description: "completion")
        responseController.phase = .command(version: "a")
        _ = connection.send(.init(type: "happy", data: ["data": true]), completion: { result in
            XCTAssertEqual(result, .failure(.internal(debugDescription: "moo")))
            expectation.fulfill()
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "happy" && invoc.request.data["data"] as? Bool == true
        }) as? HARequestInvocationSingle)

        // we test the "when something is added" flow elsewhere; skip end-to-end and invoke directly
        added.resolve(.failure(.internal(debugDescription: "moo")))
        waitForExpectations(timeout: 10.0)
    }

    func testTypedRequestCancelled() throws {
        let token = connection.send(HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])), completion: { result in
            XCTFail("should not have invoked completion when cancelled")
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }))

        token.cancel()
        XCTAssertTrue(requestController.cancelled.contains(added))
    }

    func testTypedRequestSentSuccessfullyDecodeSuccessful() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])), completion: { result in
            XCTAssertNotNil(try? result.get())
            expectation.fulfill()
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.success(.dictionary(["success": true])))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentSuccessfullyDecodeFailure() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])), completion: { result in
            switch result {
            case .success: XCTFail("expected failure")
            case let .failure(error):
                XCTAssertEqual(error, .internal(debugDescription: MockTypedRequestResult.DecodeError.intentional.localizedDescription))
            }
            expectation.fulfill()
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.success(.dictionary(["failure": true])))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentFailure() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])), completion: { result in
            switch result {
            case .success: XCTFail("expected failure")
            case let .failure(error):
                XCTAssertEqual(error, .internal(debugDescription: "direct"))
            }
            expectation.fulfill()
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.failure(.internal(debugDescription: "direct")))
        waitForExpectations(timeout: 10)
    }

    func testPlainSubscribeCancelled() throws {
        let request = HARequest(type: "subbysubsub", data: ["ok": true])

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: HAConnectionProtocol.SubscriptionHandler = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()
            requestController.cancelled.removeAll()

            let token = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)
            token.cancel()
            XCTAssertTrue(requestController.cancelled.contains(added))
        }
    }

    func testPlainSubscribeSuccess() throws {
        let request = HARequest(type: "subbysubsub", data: ["ok": true])

        let initiatedExpectation = self.expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .success(.dictionary(["yo": true])))
            initiatedExpectation.fulfill()
        }

        let handler: HAConnectionProtocol.SubscriptionHandler = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.resolve(.success(.dictionary(["yo": true])))
        }

        waitForExpectations(timeout: 10)
    }

    func testPlainSubscribeFailure() throws {
        let request = HARequest(type: "subbysubsub", data: ["ok": true])

        let initiatedExpectation = self.expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .failure(.internal(debugDescription: "you like dags?")))
            initiatedExpectation.fulfill()
        }

        let handler: HAConnectionProtocol.SubscriptionHandler = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.resolve(.failure(.internal(debugDescription: "you like dags?")))
        }

        waitForExpectations(timeout: 10)
    }

    func testPlainSubscribeEvent() throws {
        let request = HARequest(type: "subbysubsub", data: ["ok": true])

        let handlerExpectation = self.expectation(description: "event")
        handlerExpectation.expectedFulfillmentCount = 2

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: HAConnectionProtocol.SubscriptionHandler = { _, result in
            XCTAssertEqual(result, .dictionary(["event": true]))
            handlerExpectation.fulfill()
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.invoke(token: .init(handler: {}), event: .dictionary(["event": true]))
        }

        waitForExpectations(timeout: 10)
    }

    func testTypedSubscribeCancelled() throws {
        let request = HATypedSubscription<MockTypedRequestResult>(request: .init(
            type: "subbysubsub",
            data: ["ok": true]
        ))

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()
            requestController.cancelled.removeAll()

            let token = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)
            token.cancel()
            XCTAssertTrue(requestController.cancelled.contains(added))
        }
    }

    func testTypedSubscribeSuccess() throws {
        let request = HATypedSubscription<MockTypedRequestResult>(request: .init(
            type: "subbysubsub",
            data: ["ok": true]
        ))

        let initiatedExpectation = self.expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .success(.dictionary(["yo": true])))
            initiatedExpectation.fulfill()
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.resolve(.success(.dictionary(["yo": true])))
        }

        waitForExpectations(timeout: 10)
    }

    func testTypedSubscribeFailure() throws {
        let request = HATypedSubscription<MockTypedRequestResult>(request: .init(
            type: "subbysubsub",
            data: ["ok": true]
        ))

        let initiatedExpectation = self.expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .failure(.internal(debugDescription: "you like dags?")))
            initiatedExpectation.fulfill()
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _,_ in
            XCTFail("did not expect handler to be invoked")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.resolve(.failure(.internal(debugDescription: "you like dags?")))
        }

        waitForExpectations(timeout: 10)
    }

    func testTypedSubscribeEventSucceedsDecode() throws {
        let request = HATypedSubscription<MockTypedRequestResult>(request: .init(
            type: "subbysubsub",
            data: ["ok": true]
        ))

        let handlerExpectation = self.expectation(description: "event")
        handlerExpectation.expectedFulfillmentCount = 2

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, result in
            handlerExpectation.fulfill()
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.invoke(token: .init(handler: {}), event: .dictionary(["success": true]))
        }

        waitForExpectations(timeout: 10)
    }

    func testTypedSubscribeEventFailsDecode() throws {
        let request = HATypedSubscription<MockTypedRequestResult>(request: .init(
            type: "subbysubsub",
            data: ["ok": true]
        ))

        let initiated: HAConnectionProtocol.SubscriptionInitiatedHandler = { result in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, result in
            XCTFail("did not expect handler to be invoked since decode failed")
        }

        for get: () -> HACancellable in [
            { self.connection.subscribe(to: request, handler: handler) },
            { self.connection.subscribe(to: request, initiated: initiated, handler: handler) },
        ] {
            requestController.added.removeAll()

            _ = get()
            let added = try XCTUnwrap(requestController.added.first(where: { invoc in
                invoc.request.type == "subbysubsub" && invoc.request.data["ok"] as? Bool == true
            }) as? HARequestInvocationSubscription)

            added.invoke(token: .init(handler: {}), event: .dictionary(["failure": true]))
        }
    }
}

extension WebSocketEvent: Equatable {
    public static func == (lhs: WebSocketEvent, rhs: WebSocketEvent) -> Bool {
        switch (lhs, lhs) {
        case let (.binary(lhsInside), .binary(rhsInside)):
            return lhsInside == rhsInside
        case (.cancelled, .cancelled):
            return true
        case let (.connected(lhsInside), .connected(rhsInside)):
            return lhsInside == rhsInside
        case let (.disconnected(lhsInsideString, lhsInsideCode), .disconnected(rhsInsideString, rhsInsideCode)):
            return lhsInsideString == rhsInsideString
                && lhsInsideCode == rhsInsideCode
        case let (.error(lhsInside), .error(rhsInside)):
            return lhsInside as NSError? == rhsInside as NSError?
        case let (.ping(lhsInside), .ping(rhsInside)):
            return lhsInside == rhsInside
        case let (.pong(lhsInside), .pong(rhsInside)):
            return lhsInside == rhsInside
        case let (.reconnectSuggested(lhsInside), .reconnectSuggested(rhsInside)):
            return lhsInside == rhsInside
        case let (.text(lhsInside), .text(rhsInside)):
            return lhsInside == rhsInside
        case let (.viabilityChanged(lhsInside), .viabilityChanged(rhsInside)):
            return lhsInside == rhsInside
        default:
            return false
        }
    }
}

private class MockTypedRequestResult: HADataDecodable {
    enum DecodeError: Error {
        case intentional
    }

    required init(data: HAData) throws {
        if data == .dictionary(["success": true]) {
            // success
        } else if data == .dictionary(["failure": true]) {
            throw DecodeError.intentional
        } else {
            XCTFail("improper use of result")
        }
    }
}

private class FakeHAConnectionDelegate: HAConnectionDelegate {
    var states = [HAConnectionState]()
    func connection(_ connection: HAConnectionProtocol, transitionedTo state: HAConnectionState) {
        states.append(state)
        XCTAssertEqual(state, connection.state)
    }
}

private class FakeHARequestController: HARequestController {
    weak var delegate: HARequestControllerDelegate?

    var added: [HARequestInvocation] = []
    func add(_ invocation: HARequestInvocation, completion: @escaping () -> Void) {
        added.append(invocation)
        completion()
    }

    var cancelled: [HARequestInvocation] = []
    func cancel(_ request: HARequestInvocation, completion: @escaping () -> Void) {
        cancelled.append(request)
        completion()
    }

    var didPrepare = false
    func prepare(completion handler: @escaping () -> Void) {
        didPrepare = true
        handler()
    }

    var didResetActive = false
    func resetActive(completion: @escaping () -> Void) {
        didResetActive = true
        completion()
    }

    var singles: [HARequestIdentifier: HARequestInvocationSingle] = [
        1_000_999: .init(request: .init(type: "test", data: [:]), completion: { _ in
            XCTFail("unexpected completion")
        }),
    ]
    var subscriptions: [HARequestIdentifier: HARequestInvocationSubscription] = [
        1_000_999: .init(request: .init(type: "test", data: [:]), initiated: { _ in
            XCTFail("unexpected initiated")
        }, handler: { _, _ in
            XCTFail("unexpected handler")
        }),
    ]

    func single(for identifier: HARequestIdentifier) -> HARequestInvocationSingle? {
        singles[identifier]
    }

    func subscription(for identifier: HARequestIdentifier) -> HARequestInvocationSubscription? {
        subscriptions[identifier]
    }

    var cleared: [HARequestInvocationSingle] = []
    func clear(invocation: HARequestInvocationSingle, completion: @escaping () -> Void) {
        cleared.append(invocation)
        completion()
    }
}

private class FakeHAResponseController: HAResponseController {
    weak var delegate: HAResponseControllerDelegate?

    var phase: HAResponseControllerPhase = .disconnected

    var wasReset = false

    func reset() {
        wasReset = true
        phase = .disconnected
    }

    var received: [WebSocketEvent] = []
    func didReceive(event: WebSocketEvent) {
        received.append(event)
    }
}
