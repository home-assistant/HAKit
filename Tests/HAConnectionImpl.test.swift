@testable import HAKit
#if SWIFT_PACKAGE
@testable import HAKit_PromiseKit
#endif
import PromiseKit
import Starscream
import XCTest

internal class HAConnectionImplTests: XCTestCase {
    private var url: URL?
    private var engine: FakeEngine!
    private var pendingFetchAccessTokens: [(Swift.Result<String, Error>) -> Void]!
    private var connection: HAConnectionImpl!
    private var callbackQueue: DispatchQueue!
    private var queueSpecific = DispatchSpecificKey<Bool>()
    private var requestController: FakeHARequestController!
    private var responseController: FakeHAResponseController!
    private var reconnectManager: FakeHAReconnectManager!
    // swiftlint:disable:next weak_delegate
    private var delegate: FakeHAConnectionDelegate!

    private var isOnCallbackQueue: Bool {
        DispatchQueue.getSpecific(key: queueSpecific) == true
    }

    private func waitForCallbackQueue() {
        let expectation = self.expectation(description: "callback queue wait once")
        callbackQueue.async(execute: expectation.fulfill)
        waitForExpectations(timeout: 10.0)
    }

    private func waitForWorkQueue() {
        let expectation = self.expectation(description: "work queue wait once")
        connection.workQueue.async(execute: expectation.fulfill)
        waitForExpectations(timeout: 10.0)
    }

    override func setUp() {
        super.setUp()

        requestController = FakeHARequestController()
        responseController = FakeHAResponseController()
        reconnectManager = FakeHAReconnectManager()

        queueSpecific = .init()
        callbackQueue = DispatchQueue(label: "test-callback-queue")
        callbackQueue.setSpecific(key: queueSpecific, value: true)

        pendingFetchAccessTokens = []
        url = URL(string: "http://example.com/default")!
        engine = FakeEngine()
        connection = .init(
            configuration: .init(connectionInfo: { [weak self] in
                if let url = self?.url, let engine = self?.engine {
                    return try? .init(url: url, userAgent: nil, engine: engine)
                } else {
                    XCTAssertNotNil(self?.engine, "invoked after deallocated")
                    return nil
                }
            }, fetchAuthToken: { [weak self] handler in
                self?.pendingFetchAccessTokens.append(handler)
            }),
            requestController: requestController,
            responseController: responseController,
            reconnectManager: reconnectManager
        )
        connection.callbackQueue = callbackQueue

        delegate = FakeHAConnectionDelegate(connection: connection)
        connection.delegate = delegate
    }

    private func assertSent(
        identifier: HARequestIdentifier?,
        request: HARequest,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        waitForWorkQueue()

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

            XCTAssertEqual(jsonRep["type"] as? String, request.type.command)

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
        XCTAssertEqual(connection.state, .disconnected(reason: .disconnected))
    }

    func testConnectionConnect() throws {
        connection.connect()
        let expectedURL = try HAConnectionInfo(url: try XCTUnwrap(url)).webSocketURL
        XCTAssertTrue(engine.events.contains(where: { event in
            if case let .start(request) = event {
                return request.url == expectedURL
            } else {
                return false
            }
        }))
        XCTAssertTrue(reconnectManager.didStartInitial)

        // connect a second time, it shouldn't disconnect
        connection.connect()
        XCTAssertEqual(engine.events.count, 1)

        responseController.phase = .command(version: "123")
        connection.responseController(responseController, didTransitionTo: .command(version: "123"))
        waitForCallbackQueue()

        // connect a second time, it shouldn't disconnect
        connection.connect()
        XCTAssertEqual(engine.events.count, 1)
        XCTAssertTrue(requestController.added.isEmpty)
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
        url = try XCTUnwrap(url).appendingPathComponent("hi")
        let newExpectedURL = try HAConnectionInfo(url: try XCTUnwrap(url)).webSocketURL

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
        XCTAssertFalse(reconnectManager.didPermanently)
        XCTAssertFalse(reconnectManager.didTemporarily)
    }

    func testSubscribeRetryEvents() {
        requestController.retrySubscriptionsEvents = ["event1", "event2"]
        connection.connect()
        connection.connect()

        responseController.phase = .command(version: "123")
        connection.responseController(responseController, didTransitionTo: .command(version: "123"))
        waitForCallbackQueue()

        let subscriptions = requestController.added.compactMap { $0 as? HARequestInvocationSubscription }
        XCTAssertEqual(subscriptions.count, requestController.retrySubscriptionsEvents.count)

        for subscription in subscriptions {
            requestController.didResetSubscriptions = false
            subscription.invoke(token: HACancellableImpl {}, event: HAData(testJsonString: """
            {
                "event_type": "whatevs",
                "origin": "REMOTE",
                "time_fired": "2021-02-24T04:31:10.045916+00:00",
                "context": {
                    "id": "ebc9bf93dd90efc0770f1dc49096788f"
                }
            }
            """))
            waitForWorkQueue()
            waitForCallbackQueue()
            XCTAssertTrue(requestController.didResetSubscriptions)
        }
    }

    func testConnectWithoutConnectionInfo() {
        url = nil
        connection.connect()

        waitForCallbackQueue()

        XCTAssertEqual(delegate.states.last, connection.state)
        XCTAssertEqual(delegate.notifiedCount, 1)
        XCTAssertTrue(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didPermanently)

        switch connection.state {
        case let .disconnected(reason: reason):
            switch reason {
            case .waitingToReconnect(
                lastError: HAConnectionImpl.ConnectError.noConnectionInfo?,
                atLatest: _,
                retryCount: _
            ):
                // pass
                break
            default:
                XCTFail("expected waiting to reconnect")
            }
        case .connecting, .ready, .authenticating: XCTFail("expected disconnected")
        }
    }

    func testDisconnectedManually() {
        connection.connect()
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting])
        XCTAssertEqual(delegate.notifiedCount, 1)

        XCTAssertTrue(reconnectManager.didStartInitial)

        engine.events.removeAll()

        connection.disconnect()
        waitForCallbackQueue()
        XCTAssertTrue(engine.events.contains(.stop(CloseCode.goingAway.rawValue)))
        XCTAssertTrue(responseController.wasReset)
        XCTAssertTrue(reconnectManager.didPermanently)
        XCTAssertFalse(reconnectManager.didTemporarily)

        XCTAssertEqual(connection.state, .disconnected(reason: .disconnected))
        XCTAssertEqual(delegate.states.last, .disconnected(reason: .disconnected))
        XCTAssertEqual(delegate.notifiedCount, 2)
    }

    func testDisconnectedTemporarilyWithoutError() throws {
        connection.connect()
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting])
        XCTAssertEqual(delegate.notifiedCount, 1)

        engine.events.removeAll()
        connection.responseController(responseController, didTransitionTo: .disconnected(error: nil, forReset: false))
        waitForCallbackQueue()
        XCTAssertTrue(requestController.didResetActive)
        XCTAssertEqual(delegate.states.last, connection.state)
        XCTAssertEqual(delegate.notifiedCount, 2)
        XCTAssertTrue(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didPermanently)

        switch connection.state {
        case let .disconnected(reason: reason):
            switch reason {
            case .waitingToReconnect(lastError: nil, atLatest: _, retryCount: _):
                // pass
                break
            default:
                XCTFail("expected waiting to reconnect")
            }
        case .connecting, .ready, .authenticating: XCTFail("expected disconnected")
        }
    }

    func testDisconnectedTemporarilyWithError() throws {
        enum FakeError: Error {
            case error
        }

        connection.connect()

        engine.events.removeAll()
        connection.responseController(
            responseController,
            didTransitionTo: .disconnected(error: FakeError.error, forReset: false)
        )
        XCTAssertTrue(requestController.didResetActive)
        XCTAssertTrue(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didPermanently)

        switch connection.state {
        case let .disconnected(reason: reason):
            switch reason {
            case let .waitingToReconnect(lastError: error, atLatest: _, retryCount: _):
                XCTAssertEqual(FakeError.error as NSError?, error as NSError?)
            case .disconnected: XCTFail("expected waiting to reconnect")
            }
        case .connecting, .ready, .authenticating: XCTFail("expected disconnected")
        }
    }

    func testDisconnectedForReset() throws {
        enum FakeError: Error {
            case error
        }

        connection.connect()

        engine.events.removeAll()
        connection.responseController(
            responseController,
            didTransitionTo: .disconnected(error: FakeError.error, forReset: true)
        )
        XCTAssertTrue(requestController.didResetActive)
        XCTAssertFalse(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didPermanently)
        XCTAssertTrue(engine.events.isEmpty)
    }

    func testReconnectManagerWantsReconnect() {
        connection.reconnectManagerWantsReconnection(reconnectManager)
        XCTAssertFalse(reconnectManager.didPermanently)
        XCTAssertFalse(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didStartInitial)
        XCTAssertTrue(engine.events.contains(where: { event in
            if case .start = event {
                return true
            } else {
                return false
            }
        }))
    }

    func testReconnectManagerSendsPingAndSucceeds() throws {
        var result: Swift.Result<Void, Error>?

        let expectation = self.expectation(description: "ping result")

        _ = connection.reconnectManager(reconnectManager, pingWithCompletion: { thisResult in
            result = thisResult
            expectation.fulfill()
        })

        let ping = try XCTUnwrap(
            requestController.added
                .first(where: { $0.request.type == .ping }) as? HARequestInvocationSingle
        )

        ping.resolve(.success(.empty))
        waitForExpectations(timeout: 10.0)
        XCTAssertNoThrow(try XCTUnwrap(result).get())
    }

    func testReconnectManagerSendsPingAndFails() throws {
        var result: Swift.Result<Void, Error>?

        let expectation = self.expectation(description: "ping result")

        _ = connection.reconnectManager(reconnectManager, pingWithCompletion: { thisResult in
            result = thisResult
            expectation.fulfill()
        })

        let ping = try XCTUnwrap(
            requestController.added
                .first(where: { $0.request.type == .ping }) as? HARequestInvocationSingle
        )

        ping.resolve(.failure(.internal(debugDescription: "unit test")))
        waitForExpectations(timeout: 10.0)

        XCTAssertThrowsError(try XCTUnwrap(result).get()) { error in
            XCTAssertEqual(error as? HAError, .internal(debugDescription: "unit test"))
        }
    }

    func testReconnectManagerSendsPingAndCancelled() throws {
        let token = connection.reconnectManager(reconnectManager, pingWithCompletion: { _ in
            XCTFail("should not have invoked")
        })

        let ping = try XCTUnwrap(
            requestController.added
                .first(where: { $0.request.type == .ping }) as? HARequestInvocationSingle
        )

        token.cancel()
        XCTAssertTrue(requestController.cancelled.contains(ping))
    }

    func testReconnectManagerWantsDisconnect() {
        enum FakeError: Error {
            case error
        }

        connection.connect()
        engine.events.removeAll()

        connection.reconnect(reconnectManager, wantsDisconnectFor: FakeError.error)
        waitForCallbackQueue()
        XCTAssertTrue(responseController.wasReset)
        XCTAssertTrue(reconnectManager.didTemporarily)
        XCTAssertFalse(reconnectManager.didPermanently)

        switch connection.state {
        case let .disconnected(reason: reason):
            switch reason {
            case let .waitingToReconnect(lastError: error, atLatest: _, retryCount: _):
                XCTAssertEqual(FakeError.error as NSError?, error as NSError?)
            case .disconnected: XCTFail("expected waiting to reconnect")
            }
        case .connecting, .ready, .authenticating: XCTFail("expected disconnected")
        }
    }

    func testAutomaticConnection() throws {
        XCTAssertTrue(engine.events.isEmpty)

        connection.connectAutomatically = false
        connection.send(.init(type: "test", data: [:]), completion: { _ in })
        connection.subscribe(to: .init(type: "test", data: [:]), handler: { _, _ in })
        XCTAssertTrue(engine.events.isEmpty)

        connection.connectAutomatically = true

        connection.send(.init(type: "test", data: [:]), completion: { _ in })
        XCTAssertTrue(engine.events.contains(where: { event in
            if case .start = event {
                return true
            } else {
                return false
            }
        }))

        engine.events.removeAll()
        connection.send(.init(type: "test", data: [:]), completion: { _ in })

        // don't try and call connect _again_
        XCTAssertFalse(engine.events.contains(where: { event in
            if case .start = event {
                return true
            } else {
                return false
            }
        }))

        connection.disconnect()
        engine.events.removeAll()

        connection.subscribe(to: .init(type: "test", data: [:]), handler: { _, _ in })
        XCTAssertTrue(engine.events.contains(where: { event in
            if case .start = event {
                return true
            } else {
                return false
            }
        }))

        engine.events.removeAll()
        connection.subscribe(to: .init(type: "test", data: [:]), handler: { _, _ in })

        // don't try and call connect _again_
        XCTAssertFalse(engine.events.contains(where: { event in
            if case .start = event {
                return true
            } else {
                return false
            }
        }))
    }

    func testShouldSendRequestsDuringCommandPhase() {
        responseController.phase = .disconnected(error: nil, forReset: false)
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

    func testConnectedSendsAuthTokenGetInvokedTwice() throws {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .auth
        connection.responseController(responseController, didTransitionTo: .auth)

        XCTAssertTrue(engine.events.isEmpty)

        waitForCallbackQueue()

        XCTAssertEqual(delegate.states, [.connecting, .authenticating])
        XCTAssertEqual(delegate.notifiedCount, 2)

        let tokenBlock = try XCTUnwrap(pendingFetchAccessTokens.last)

        tokenBlock(.success("token!"))
        try assertSent(identifier: nil, request: .init(
            type: .auth,
            data: ["access_token": "token!"]
        ))

        let previousCount = engine.events.count

        tokenBlock(.success("second!"))
        XCTAssertEqual(engine.events.count, previousCount)
    }

    func testConnectedSendsAuthTokenGetSucceeds() throws {
        connection.connect()

        engine.events.removeAll()

        responseController.phase = .auth
        connection.responseController(responseController, didTransitionTo: .auth)
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting, .authenticating])
        XCTAssertEqual(delegate.notifiedCount, 2)

        XCTAssertTrue(engine.events.isEmpty)

        try XCTUnwrap(pendingFetchAccessTokens.last)(.success("token!"))
        try assertSent(identifier: nil, request: .init(
            type: .auth,
            data: ["access_token": "token!"]
        ))
    }

    func testConnectedSendsAuthTokenGetFails() throws {
        connection.connect()
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting])
        XCTAssertEqual(delegate.notifiedCount, 1)

        engine.events.removeAll()

        responseController.phase = .auth
        connection.responseController(responseController, didTransitionTo: .auth)
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting, .authenticating])
        XCTAssertEqual(delegate.notifiedCount, 2)

        XCTAssertTrue(engine.events.isEmpty)

        XCTAssertEqual(pendingFetchAccessTokens.count, 1)
        let accessTokenBlock = try XCTUnwrap(pendingFetchAccessTokens.get(throwing: 0))

        enum TestError: Error {
            case any
        }

        accessTokenBlock(.failure(TestError.any))
        waitForCallbackQueue()
        XCTAssertTrue(engine.events.contains(.stop(CloseCode.goingAway.rawValue)))
        XCTAssertEqual(delegate.notifiedCount, 3)

        let last = try XCTUnwrap(delegate.states.last)
        switch last {
        case .disconnected(reason: .waitingToReconnect):
            XCTAssertTrue(reconnectManager.didTemporarily)
        default:
            XCTFail("last state should have been disconnected, got \(last)")
        }
    }

    func testCommandPreparesRequestsAndInformsReconnectManager() {
        connection.connect()
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting])
        XCTAssertEqual(delegate.notifiedCount, 1)

        engine.events.removeAll()

        responseController.phase = .command(version: "123")
        connection.responseController(responseController, didTransitionTo: .command(version: "123"))
        waitForCallbackQueue()
        XCTAssertEqual(delegate.states, [.connecting, .ready(version: "123")])
        XCTAssertEqual(delegate.notifiedCount, 2)

        XCTAssertTrue(requestController.didPrepare)
        XCTAssertTrue(reconnectManager.didFinish)
    }

    func testReceivedEventForwardedToResponseController() throws {
        connection.connect()

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
            connection.didReceive(event: event, client: try XCTUnwrap(connection.connection))
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
        XCTAssertEqual(delegate.notifiedCount, 0)
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
        let expectedResult: Swift.Result<HAData, HAError> = .success(.dictionary(["yep": true]))

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
        let expectedResult: Swift.Result<HAData, HAError> = .success(.dictionary(["yep": true]))

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

        XCTAssertTrue(requestController.added.isEmpty)
    }

    func testPlainSendCancelled() throws {
        let token = connection.send(.init(type: "test1", data: ["data": true]), completion: { _ in
            XCTFail("should not have invoked completion when cancelled")
        })

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "test1" && invoc.request.data["data"] as? Bool == true
        }))

        token.cancel()
        XCTAssertTrue(requestController.cancelled.contains(added))
    }

    func testPlainSendCancelledPromise() throws {
        let (_, cancel) = connection.send(.init(type: "test1", data: ["data": true]))

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "test1" && invoc.request.data["data"] as? Bool == true
        }))

        cancel()
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

    func testPlainSendSentSuccessfulPromise() throws {
        let expectation = self.expectation(description: "completion")
        responseController.phase = .command(version: "a")

        _ = connection.send(.init(type: "happy", data: ["data": true])).promise.done { data in
            XCTAssertEqual(data, .dictionary(["still_happy": true]))
            expectation.fulfill()
        }.cauterize()

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

    func testPlainSendSentFailurePromise() throws {
        let expectation = self.expectation(description: "completion")
        responseController.phase = .command(version: "a")
        _ = connection.send(.init(type: "happy", data: ["data": true])).promise.catch { error in
            XCTAssertEqual(error as? HAError, .internal(debugDescription: "moo"))
            expectation.fulfill()
        }

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "happy" && invoc.request.data["data"] as? Bool == true
        }) as? HARequestInvocationSingle)

        // we test the "when something is added" flow elsewhere; skip end-to-end and invoke directly
        added.resolve(.failure(.internal(debugDescription: "moo")))
        waitForExpectations(timeout: 10.0)
    }

    func testTypedRequestCancelled() throws {
        let token = connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])),
            completion: { _ in
                XCTFail("should not have invoked completion when cancelled")
            }
        )

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }))

        token.cancel()
        XCTAssertTrue(requestController.cancelled.contains(added))
    }

    func testTypedRequestCancelledPromise() throws {
        let (_, cancel) = connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:]))
        )

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }))

        cancel()
        XCTAssertTrue(requestController.cancelled.contains(added))
    }

    func testTypedRequestSentSuccessfullyDecodeSuccessful() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])),
            completion: { result in
                XCTAssertNotNil(try? result.get())
                expectation.fulfill()
            }
        )

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.success(.dictionary(["success": true])))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentSuccessfulPromise() throws {
        let expectation = self.expectation(description: "completion")
        connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:]))
        ).promise.done { _ in
            expectation.fulfill()
        }.cauterize()

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.success(.dictionary(["success": true])))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentSuccessfullyDecodeFailure() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])),
            completion: { result in
                switch result {
                case .success: XCTFail("expected failure")
                case let .failure(error):
                    XCTAssertEqual(
                        error,
                        .internal(debugDescription: String(describing: MockTypedRequestResult.DecodeError.intentional))
                    )
                }
                expectation.fulfill()
            }
        )

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.success(.dictionary(["failure": true])))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentFailure() throws {
        let expectation = self.expectation(description: "completion")
        _ = connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:])),
            completion: { result in
                switch result {
                case .success: XCTFail("expected failure")
                case let .failure(error):
                    XCTAssertEqual(error, .internal(debugDescription: "direct"))
                }
                expectation.fulfill()
            }
        )

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.failure(.internal(debugDescription: "direct")))
        waitForExpectations(timeout: 10)
    }

    func testTypedRequestSentFailurePromise() throws {
        let expectation = self.expectation(description: "completion")
        connection.send(
            HATypedRequest<MockTypedRequestResult>(request: .init(type: "typed_type", data: [:]))
        ).promise.catch { error in
            XCTAssertEqual(error as? HAError, .internal(debugDescription: "direct"))
            expectation.fulfill()
        }

        let added = try XCTUnwrap(requestController.added.first(where: { invoc in
            invoc.request.type == "typed_type"
        }) as? HARequestInvocationSingle)

        added.resolve(.failure(.internal(debugDescription: "direct")))
        waitForExpectations(timeout: 10)
    }

    func testPlainSubscribeCancelled() throws {
        let request = HARequest(type: "subbysubsub", data: ["ok": true])

        let initiated: HAConnection.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: HAConnection.SubscriptionHandler = { _, _ in
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

        let initiatedExpectation = expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnection.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .success(.dictionary(["yo": true])))
            initiatedExpectation.fulfill()
        }

        let handler: HAConnection.SubscriptionHandler = { _, _ in
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

        let initiatedExpectation = expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnection.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .failure(.internal(debugDescription: "you like dags?")))
            initiatedExpectation.fulfill()
        }

        let handler: HAConnection.SubscriptionHandler = { _, _ in
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

        let handlerExpectation = expectation(description: "event")
        handlerExpectation.expectedFulfillmentCount = 2

        let initiated: HAConnection.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: HAConnection.SubscriptionHandler = { _, result in
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

        let initiated: HAConnection.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, _ in
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

        let initiatedExpectation = expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnection.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .success(.dictionary(["yo": true])))
            initiatedExpectation.fulfill()
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, _ in
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

        let initiatedExpectation = expectation(description: "initiated")
        initiatedExpectation.expectedFulfillmentCount = 1

        let initiated: HAConnection.SubscriptionInitiatedHandler = { result in
            XCTAssertEqual(result, .failure(.internal(debugDescription: "you like dags?")))
            initiatedExpectation.fulfill()
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, _ in
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

        let handlerExpectation = expectation(description: "event")
        handlerExpectation.expectedFulfillmentCount = 2

        let initiated: HAConnection.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, _ in
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

        let initiated: HAConnection.SubscriptionInitiatedHandler = { _ in
            XCTFail("did not expect handler to be invoked")
        }

        let handler: (HACancellable, MockTypedRequestResult) -> Void = { _, _ in
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

    func testCachesContainerExists() throws {
        let container = connection.caches
        XCTAssertEqual(ObjectIdentifier(container.connection), ObjectIdentifier(connection))
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
    private var token: Any?

    init(connection: HAConnectionImpl) {
        self.token = NotificationCenter.default.addObserver(
            forName: HAConnectionState.didTransitionToStateNotification,
            object: connection,
            queue: nil,
            using: { [weak self] _ in
                self?.notifiedCount += 1
            }
        )
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }

    var states = [HAConnectionState]()
    var notifiedCount = 0
    func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        states.append(state)
    }
}

private class FakeHARequestController: HARequestController {
    weak var delegate: HARequestControllerDelegate?
    var workQueue: DispatchQueue = .main

    var added: [HARequestInvocation] = []
    func add(_ invocation: HARequestInvocation) {
        added.append(invocation)
    }

    var cancelled: [HARequestInvocation] = []
    func cancel(_ request: HARequestInvocation) {
        cancelled.append(request)
    }

    var retrySubscriptionsEvents: [HAEventType] = []

    var didResetSubscriptions = false
    func retrySubscriptions() {
        didResetSubscriptions = true
    }

    var didPrepare = false
    func prepare() {
        didPrepare = true
    }

    var didResetActive = false
    func resetActive() {
        didResetActive = true
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
    func clear(invocation: HARequestInvocationSingle) {
        cleared.append(invocation)
    }
}

private class FakeHAResponseController: HAResponseController {
    weak var delegate: HAResponseControllerDelegate?
    var workQueue: DispatchQueue = .main

    var phase: HAResponseControllerPhase = .disconnected(error: nil, forReset: true)

    var wasReset = false

    func reset() {
        wasReset = true
        phase = .disconnected(error: nil, forReset: true)
    }

    var received: [WebSocketEvent] = []
    func didReceive(event: WebSocketEvent) {
        received.append(event)
    }

    func didReceive(
        for identifier: HARequestIdentifier,
        urlResponse: URLResponse?,
        data: Data?, error: Error?
    ) {
        fatalError()
    }
}

private class FakeHAReconnectManager: HAReconnectManager {
    weak var delegate: HAReconnectManagerDelegate?

    var reason: HAConnectionState.DisconnectReason = .disconnected

    var didFinish = false
    func didFinishConnect() {
        didFinish = true
    }

    var didStartInitial = false
    func didStartInitialConnect() {
        didStartInitial = true
    }

    var didPermanently = false
    func didDisconnectPermanently() {
        didPermanently = true
        reason = .disconnected
    }

    var didTemporarily = false
    var didTemporarilyError: Error?
    func didDisconnectTemporarily(error: Error?) {
        didTemporarily = true
        didTemporarilyError = error
        reason = .waitingToReconnect(lastError: error, atLatest: Date(), retryCount: 0)
    }
}
