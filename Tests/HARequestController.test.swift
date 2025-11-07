@testable import HAKit
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
        controller.workQueue = DispatchQueue(label: "unit-test-work-queue")
    }

    func testAddingWhenNotAllowed() {
        controller.add(.init(request: .init(type: "test1", data: [:])))
        XCTAssertTrue(delegate.didPrepare.isEmpty)

        // transition to allowed
        delegate.allowedSendKinds = .all

        controller.prepare()
        XCTAssertFalse(delegate.didPrepare.isEmpty)
    }

    func testAddingWhenAllowed() throws {
        delegate.allowedSendKinds = .all

        controller.add(.init(request: .init(type: "test1", data: [:])))
        controller.add(.init(request: .init(type: "test2", data: [:])))
        XCTAssertEqual(delegate.didPrepare.count, 2)

        let allEvents = try [
            delegate.didPrepare.get(throwing: 0),
            delegate.didPrepare.get(throwing: 1),
        ].sorted(by: { lhs, rhs in
            lhs.request.type < rhs.request.type
        })

        let event1 = allEvents[0]
        let event2 = allEvents[1]

        XCTAssertNotEqual(event1.identifier.rawValue, event2.identifier.rawValue)

        XCTAssertEqual(event1.request.type.command, "test1")
        XCTAssertGreaterThan(event1.identifier.rawValue, 0)

        XCTAssertEqual(event2.request.type.command, "test2")
        XCTAssertGreaterThan(event2.identifier.rawValue, 0)
    }

    func testAddedPerpetualAndReset() throws {
        delegate.allowedSendKinds = .all

        // will completed before reset
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: .rest(.get, "test1"), data: [:]),
            completion: { _ in }
        )
        // will not be completed before reset
        let invoc2 = HARequestInvocationSingle(
            request: .init(type: .rest(.post, "test2"), data: [:]),
            completion: { _ in }
        )
        // will be reset
        let invoc3 = HARequestInvocationSingle(
            request: .init(type: .webSocket("test3"), data: [:]),
            completion: { _ in }
        )

        controller.add(invoc1)
        controller.add(invoc2)
        controller.add(invoc3)

        XCTAssertEqual(delegate.didPrepare.count, 3)
        delegate.didPrepare.removeAll()

        let invocation = try controller.single(for: XCTUnwrap(invoc1.identifier))
        XCTAssertEqual(invocation, invoc1)
        invocation?.resolve(.success(.empty))

        controller.resetActive()

        // should still be available even after reset
        XCTAssertNotNil(try controller.single(for: XCTUnwrap(invoc2.identifier)))

        XCTAssertFalse(invoc1.needsAssignment)
        XCTAssertFalse(invoc2.needsAssignment)
        XCTAssertTrue(invoc3.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)

        let types = Set(delegate.didPrepare.map(\.request.type.command))
        XCTAssertEqual(types, Set(["test3"]))
    }

    func testAddedOnlyRest() {
        delegate.allowedSendKinds = .rest

        let invoc1 = HARequestInvocationSingle(
            request: .init(type: .rest(.get, "test1"), data: [:]),
            completion: { _ in }
        )
        // will be reset
        let invoc2 = HARequestInvocationSingle(
            request: .init(type: .webSocket("test2"), data: [:]),
            completion: { _ in }
        )

        controller.add(invoc1)
        controller.add(invoc2)

        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()
        controller.resetActive()

        // should still be available even after reset
        XCTAssertNotNil(try controller.single(for: XCTUnwrap(invoc1.identifier)))

        XCTAssertFalse(invoc1.needsAssignment)
        XCTAssertTrue(invoc2.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)

        delegate.allowedSendKinds = .all

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)

        let types = Set(delegate.didPrepare.map(\.request.type.command))
        XCTAssertEqual(types, Set(["test2"]))
    }

    func testAddedAndResetActive() throws {
        delegate.allowedSendKinds = .all

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

        controller.add(invoc1)
        controller.add(invoc2)
        controller.add(invoc3)
        controller.add(invoc4)

        XCTAssertEqual(delegate.didPrepare.count, 4)
        delegate.didPrepare.removeAll()

        let invocation = try controller.single(for: XCTUnwrap(invoc1.identifier))
        XCTAssertEqual(invocation, invoc1)
        invocation?.resolve(.success(.empty))

        controller.resetActive()

        XCTAssertFalse(invoc1.needsAssignment)
        XCTAssertFalse(invoc2.needsAssignment)
        XCTAssertTrue(invoc3.needsAssignment)
        XCTAssertTrue(invoc4.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 2)

        let types = Set(delegate.didPrepare.map(\.request.type.command))
        XCTAssertEqual(types, Set(["test3", "test4"]))
    }

    func testAddingWriteRequestAllowed() {
        delegate.allowedSendKinds = .all
        controller.add(.init(request: .init(type: .sttData(.init(rawValue: 1)))))
        XCTAssertEqual(delegate.didPrepare.count, 1)
    }

    func testCancelSingleBeforeSent() {
        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in }
        )

        controller.add(invocation)
        controller.cancel(invocation)

        XCTAssertFalse(invocation.needsAssignment)

        delegate.allowedSendKinds = .all
        controller.prepare()

        XCTAssertTrue(delegate.didPrepare.isEmpty)
    }

    func testCancelSingleAfterSent() {
        delegate.allowedSendKinds = .all

        var didCallCompletion = false

        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in didCallCompletion = true }
        )

        controller.add(invocation)

        XCTAssertNotNil(invocation.identifier)

        controller.cancel(invocation)

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
        controller.add(invocation)

        controller.cancel(invocation)
        controller.cancel(invocation) // intentionally calling twice

        XCTAssertFalse(invocation.needsAssignment)

        delegate.allowedSendKinds = .all
        controller.prepare()

        XCTAssertTrue(delegate.didPrepare.isEmpty)
    }

    func testCancelSubscriptionAfterSent() throws {
        delegate.allowedSendKinds = .all

        let invocation = HARequestInvocationSubscription(
            request: .init(type: "test1", data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
        )
        controller.add(invocation)

        let identifier = try XCTUnwrap(invocation.identifier)
        XCTAssertEqual(controller.subscription(for: identifier), invocation)

        controller.cancel(invocation)
        controller.cancel(invocation) // intentionally calling twice

        XCTAssertEqual(delegate.didPrepare.count, 2)
        XCTAssertFalse(invocation.needsAssignment)

        let cancel = try delegate.didPrepare.get(throwing: 1)
        XCTAssertEqual(cancel.request.type, .unsubscribeEvents)
        XCTAssertEqual(cancel.request.data["subscription"] as? Int, identifier.rawValue)

        // just invoking the completion handler to make sure it doesn't crash
        controller.single(for: cancel.identifier)?.resolve(.success(.empty))
    }

    func testClearSingle() {
        delegate.allowedSendKinds = .all

        let invocation = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in }
        )
        controller.add(invocation)

        XCTAssertNotNil(invocation.identifier)

        controller.clear(invocation: invocation)

        XCTAssertNil(try controller.single(for: XCTUnwrap(invocation.identifier)))
    }

    func testRetrySubscriptions() throws {
        XCTAssertEqual(Set(controller.retrySubscriptionsEvents), Set([.componentLoaded, .coreConfigUpdated]))

        // failures
        let invocation1 = HARequestInvocationSubscription(
            request: .init(type: "try1", data: [:]),
            initiated: nil,
            handler: { _, _ in }
        )
        let invocation2 = HARequestInvocationSubscription(
            request: .init(type: "try2", data: [:]),
            initiated: nil,
            handler: { _, _ in }
        )
        // successes
        let invocation3 = HARequestInvocationSubscription(
            request: .init(type: "try3", data: [:]),
            initiated: nil,
            handler: { _, _ in }
        )
        // not initiated at all
        let invocation4 = HARequestInvocationSubscription(
            request: .init(type: "try4", data: [:]),
            initiated: nil,
            handler: { _, _ in }
        )

        delegate.allowedSendKinds = .all
        controller.add(invocation1)
        controller.add(invocation2)
        controller.add(invocation3)
        controller.add(invocation4)
        XCTAssertEqual(delegate.didPrepare.count, 4)

        for (request, identifier) in delegate.didPrepare {
            switch request.type {
            case "try1", "try2":
                controller.subscription(for: identifier)?.resolve(.failure(.internal(debugDescription: "unit-test")))
            case "try3":
                controller.subscription(for: identifier)?.resolve(.success(.empty))
            case "try4": break
            default: break
            }
        }

        delegate.didPrepare = []

        let date1 = Date(timeIntervalSinceNow: 1000)
        HAGlobal.date = { date1 }
        controller.retrySubscriptions()
        XCTAssertEqual(delegate.didPrepare.count, 0)
        let fireDate1 = try XCTUnwrap(controller.retrySubscriptionsTimer).fireDate

        XCTAssertEqual(fireDate1, date1.addingTimeInterval(5.0))

        let date2 = date1.addingTimeInterval(100)
        HAGlobal.date = { date2 }
        controller.retrySubscriptions()
        XCTAssertEqual(delegate.didPrepare.count, 0)
        let fireDate2 = try XCTUnwrap(controller.retrySubscriptionsTimer).fireDate

        XCTAssertEqual(fireDate2, date2.addingTimeInterval(5.0))

        XCTAssertGreaterThan(fireDate2, fireDate1)

        try XCTUnwrap(controller.retrySubscriptionsTimer).fire()
        XCTAssertEqual(delegate.didPrepare.count, 2)
        XCTAssertNil(controller.retrySubscriptionsTimer)

        XCTAssertEqual(
            Set(delegate.didPrepare.map(\.request.type.command)),
            Set(["try1", "try2"])
        )
    }

    // MARK: - Retry Timeout Tests

    func testResetActiveWithMaximumDateNotReached() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with duration, will not be completed
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], retryDuration: .init(value: 10, unit: .seconds)),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 5 seconds (before duration expires)
        HAGlobal.date = { startDate.addingTimeInterval(5.0) }

        controller.resetActive()

        // Should be ready to retry
        XCTAssertTrue(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)

        let types = Set(delegate.didPrepare.map(\.request.type.command))
        XCTAssertEqual(types, Set(["test1"]))
    }

    func testResetActiveWithMaximumDatePassed() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with duration, will not be completed
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], retryDuration: .init(value: 10, unit: .seconds)),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 15 seconds (past duration)
        HAGlobal.date = { startDate.addingTimeInterval(15.0) }

        controller.resetActive()

        // Should NOT be ready to retry (removed from pending)
        XCTAssertFalse(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)
    }

    func testResetActiveWithMixedMaximumDates() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with short duration (will expire)
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], retryDuration: .init(value: 5, unit: .seconds)),
            completion: { _ in }
        )
        // Request with long duration (will not expire)
        let invoc2 = HARequestInvocationSingle(
            request: .init(type: "test2", data: [:], retryDuration: .init(value: 20, unit: .seconds)),
            completion: { _ in }
        )
        // Request with no duration (will never expire)
        let invoc3 = HARequestInvocationSingle(
            request: .init(type: "test3", data: [:], retryDuration: nil),
            completion: { _ in }
        )

        controller.add(invoc1)
        controller.add(invoc2)
        controller.add(invoc3)
        XCTAssertEqual(delegate.didPrepare.count, 3)
        delegate.didPrepare.removeAll()

        // Move time forward by 10 seconds
        HAGlobal.date = { startDate.addingTimeInterval(10.0) }

        controller.resetActive()

        // invoc1 should be expired and removed
        XCTAssertFalse(invoc1.needsAssignment)
        // invoc2 and invoc3 should be ready to retry
        XCTAssertTrue(invoc2.needsAssignment)
        XCTAssertTrue(invoc3.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 2)

        let types = Set(delegate.didPrepare.map(\.request.type.command))
        XCTAssertEqual(types, Set(["test2", "test3"]))
    }

    func testResetActiveWithNoMaximumDateNeverExpires() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with no duration
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], retryDuration: nil),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 1 hour
        HAGlobal.date = { startDate.addingTimeInterval(3600.0) }

        controller.resetActive()

        // Should still be ready to retry
        XCTAssertTrue(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)
    }

    func testResetActiveWithShouldRetryFalseAndMaximumDatePassed() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with shouldRetry: false
        let invoc1 = HARequestInvocationSingle(
            request: .init(
                type: "test1",
                data: [:],
                shouldRetry: false,
                retryDuration: .init(value: 10, unit: .seconds)
            ),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward past duration
        HAGlobal.date = { startDate.addingTimeInterval(15.0) }

        controller.resetActive()

        // Should not retry because shouldRetry is false (duration check is secondary)
        XCTAssertFalse(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)
    }

    func testResetActiveSubscriptionWithMaximumDate() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Subscription with duration
        let invoc1 = HARequestInvocationSubscription(
            request: .init(type: "test1", data: [:], retryDuration: .init(value: 10, unit: .seconds)),
            initiated: { _ in },
            handler: { _, _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward past duration
        HAGlobal.date = { startDate.addingTimeInterval(15.0) }

        controller.resetActive()

        // Should not be ready to retry (removed from pending)
        XCTAssertFalse(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)
    }

    func testResetActiveDefaultMaximumDateOfTenSeconds() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request using default duration (should be 10 seconds)
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:]),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 9 seconds (within default duration)
        HAGlobal.date = { startDate.addingTimeInterval(9.0) }
        controller.resetActive()
        XCTAssertTrue(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Reset again with time at 11 seconds (past default duration)
        HAGlobal.date = { startDate.addingTimeInterval(11.0) }
        controller.resetActive()
        XCTAssertFalse(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)
    }

    func testResetActiveWithDifferentUnits() throws {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        delegate.allowedSendKinds = .all

        // Request with minutes
        let invoc1 = HARequestInvocationSingle(
            request: .init(type: "test1", data: [:], retryDuration: .init(value: 2, unit: .minutes)),
            completion: { _ in }
        )

        controller.add(invoc1)
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 1 minute (within duration)
        HAGlobal.date = { startDate.addingTimeInterval(60.0) }
        controller.resetActive()
        XCTAssertTrue(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 1)
        delegate.didPrepare.removeAll()

        // Move time forward by 3 minutes (past duration)
        HAGlobal.date = { startDate.addingTimeInterval(180.0) }
        controller.resetActive()
        XCTAssertFalse(invoc1.needsAssignment)

        controller.prepare()
        XCTAssertEqual(delegate.didPrepare.count, 0)
    }
}

private class TestHARequestControllerDelegate: HARequestControllerDelegate {
    var allowedSendKinds: HARequestControllerAllowedSendKind = []

    func requestControllerAllowedSendKinds(_ requestController: HARequestController)
        -> HARequestControllerAllowedSendKind {
        allowedSendKinds
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
