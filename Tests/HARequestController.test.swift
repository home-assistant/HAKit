@testable import HAWebSocket
import XCTest

internal class HARequestControllerTests: XCTestCase {
    private var controller: HARequestControllerImpl!
    // swiftlint:disable:next weak_delegate
    private var delegate: TestHARequestControllerDelegate!

    override func setUp() {
        super.setUp()

        delegate = TestHARequestControllerDelegate()
        controller = HARequestControllerImpl()
        controller.delegate = delegate
    }

    func testAddingWhenNotAllowed() {
        let expectation1 = expectation(description: "add")
        controller.add(.init(request: .init(type: "test1", data: [:]))) {
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        XCTAssertTrue(delegate.didPrepare.isEmpty)

        // transition to allowed
        delegate.shouldSendRequests = true

        let expectation2 = expectation(description: "prepare finish")
        controller.prepare {
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        XCTAssertFalse(delegate.didPrepare.isEmpty)
    }

    func testAddingWhenAllowed() throws {
        delegate.shouldSendRequests = true

        let expectation1 = expectation(description: "add")
        controller.add(.init(request: .init(type: "test1", data: [:]))) {
            expectation1.fulfill()
        }
        let expectation2 = expectation(description: "add")
        controller.add(.init(request: .init(type: "test2", data: [:]))) {
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(delegate.didPrepare.count, 2)

        let allEvents = [
            try delegate.didPrepare.get(throwing: 0),
            try delegate.didPrepare.get(throwing: 1),
        ].sorted(by: { lhs, rhs in
            lhs.request.type.rawValue < rhs.request.type.rawValue
        })

        let event1 = allEvents[0]
        let event2 = allEvents[1]

        XCTAssertNotEqual(event1.identifier.rawValue, event2.identifier.rawValue)

        XCTAssertEqual(event1.request.type.rawValue, "test1")
        XCTAssertGreaterThan(event1.identifier.rawValue, 0)

        XCTAssertEqual(event2.request.type.rawValue, "test2")
        XCTAssertGreaterThan(event2.identifier.rawValue, 0)
    }

    func testAddedAndResetActive() throws {
        delegate.shouldSendRequests = true

        // will completed
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], shouldRetry: true),
            completion: { _ in }
        )
        // will not be completed, but shouldn't retry
        let invoc2 = HARequestInvocationSubscription(
            request: .init(type: "test1", data: [:], shouldRetry: false),
            initiated: { _ in },
            handler: { _, _ in }
        )
        // will not be completed, but should retry
        let invoc3 = HARequestInvocationSingle(
            request: .init(type: "test3", data: [:], shouldRetry: true),
            completion: { _ in }
        )
        // will not be completed, but should retry
        let invoc4 = HARequestInvocationSubscription(
            request: .init(type: "test4", data: [:], shouldRetry: true),
            initiated: { _ in },
            handler: { _, _ in }
        )

        let expectationAdds = expectation(description: "adds")
        expectationAdds.expectedFulfillmentCount = 4

        controller.add(invoc1, completion: expectationAdds.fulfill)
        controller.add(invoc2, completion: expectationAdds.fulfill)
        controller.add(invoc3, completion: expectationAdds.fulfill)
        controller.add(invoc4, completion: expectationAdds.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(delegate.didPrepare.count, 4)
        delegate.didPrepare.removeAll()

        let invocation = controller.single(for: try XCTUnwrap(invoc1.identifier))
        XCTAssertEqual(invocation, invoc1)
        invocation?.resolve(.success(.empty))

        let expectationReset = expectation(description: "reset")
        controller.resetActive(completion: expectationReset.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertFalse(invoc1.needsAssignment)
        XCTAssertFalse(invoc2.needsAssignment)
        XCTAssertTrue(invoc3.needsAssignment)
        XCTAssertTrue(invoc4.needsAssignment)

        let expectationPrepare = expectation(description: "prepare")
        controller.prepare(completion: expectationPrepare.fulfill)
        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(delegate.didPrepare.count, 2)

        let types = Set(delegate.didPrepare.map(\.request.type.rawValue))
        XCTAssertEqual(types, Set(["test3", "test4"]))
    }

    func testCancelSingleBeforeSent() {
        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in }
        )
        let expectationAdd = expectation(description: "add")
        controller.add(invocation, completion: expectationAdd.fulfill)
        waitForExpectations(timeout: 10.0)

        let expectationCancel = expectation(description: "cancel")
        controller.cancel(invocation, completion: expectationCancel.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertFalse(invocation.needsAssignment)

        delegate.shouldSendRequests = true
        let expectationPrepare = expectation(description: "prepare")
        controller.prepare(completion: expectationPrepare.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(delegate.didPrepare.isEmpty)
    }

    func testCancelSingleAfterSent() {
        delegate.shouldSendRequests = true

        var didCallCompletion = false

        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in didCallCompletion = true }
        )
        let expectationAdd = expectation(description: "add")
        controller.add(invocation, completion: expectationAdd.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertNotNil(invocation.identifier)

        let expectationCancel = expectation(description: "cancel")
        controller.cancel(invocation, completion: expectationCancel.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(delegate.didPrepare.count, 1)
        XCTAssertFalse(invocation.needsAssignment)

        invocation.resolve(.success(.empty))
        XCTAssertFalse(didCallCompletion)
    }

    func testCancelSubscriptionBeforeSent() {
        let invocation = HARequestInvocationSubscription(
            request: .init(type: "test1", data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
        )
        let expectationAdd = expectation(description: "add")
        controller.add(invocation, completion: expectationAdd.fulfill)
        waitForExpectations(timeout: 10.0)

        let expectationCancel = expectation(description: "cancel")
        controller.cancel(invocation, completion: expectationCancel.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertFalse(invocation.needsAssignment)

        delegate.shouldSendRequests = true
        let expectationPrepare = expectation(description: "prepare")
        controller.prepare(completion: expectationPrepare.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(delegate.didPrepare.isEmpty)
    }

    func testCancelSubscriptionAfterSent() throws {
        delegate.shouldSendRequests = true

        let invocation = HARequestInvocationSubscription(
            request: .init(type: "test1", data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
        )
        let expectationAdd = expectation(description: "add")
        controller.add(invocation, completion: expectationAdd.fulfill)
        waitForExpectations(timeout: 10.0)

        let identifier = try XCTUnwrap(invocation.identifier)
        XCTAssertEqual(controller.subscription(for: identifier), invocation)

        let expectationCancel = expectation(description: "cancel")
        controller.cancel(invocation, completion: expectationCancel.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(delegate.didPrepare.count, 2)
        XCTAssertFalse(invocation.needsAssignment)

        let cancel = try delegate.didPrepare.get(throwing: 1)
        XCTAssertEqual(cancel.request.type, .unsubscribeEvents)
        XCTAssertEqual(cancel.request.data["subscription"] as? Int, identifier.rawValue)

        // just invoking the completion handler to make sure it doesn't crash
        controller.single(for: cancel.identifier)?.resolve(.success(.empty))
    }

    func testClearSingle() {
        delegate.shouldSendRequests = true

        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in }
        )
        let expectationAdd = expectation(description: "add")
        controller.add(invocation, completion: expectationAdd.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertNotNil(invocation.identifier)

        let expectationClear = expectation(description: "clear")
        controller.clear(invocation: invocation, completion: expectationClear.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertNil(controller.single(for: try XCTUnwrap(invocation.identifier)))
    }
}

private class TestHARequestControllerDelegate: HARequestControllerDelegate {
    var shouldSendRequests = false

    func requestControllerShouldSendRequests(_ requestController: HARequestController) -> Bool {
        shouldSendRequests
    }

    var didPrepare: [(request: HARequest, identifier: HARequestIdentifier)] = []

    func requestController(
        _ requestController: HARequestController,
        didPrepareRequest request: HARequest,
        with identifier: HARequestIdentifier
    ) {
        didPrepare.append((request: request, identifier: identifier))
    }
}
