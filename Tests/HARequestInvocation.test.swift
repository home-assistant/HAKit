@testable import HAKit
import XCTest

internal class HARequestInvocationTests: XCTestCase {
    func testEquality() {
        let request = HARequest(type: .callService, data: [:])
        let invocation1 = HARequestInvocation(request: request)
        let invocation2 = HARequestInvocation(request: request)
        XCTAssertEqual(invocation1, invocation1)
        XCTAssertEqual(invocation2, invocation2)
        XCTAssertNotEqual(invocation1, invocation2)
        XCTAssertNotEqual(invocation1.hashValue, invocation2.hashValue)
    }

    func testNeedsAssignment() {
        let invocation = HARequestInvocation(request: .init(
            type: .renderTemplate,
            data: [:]
        ))
        XCTAssertTrue(invocation.needsAssignment)

        invocation.identifier = 55
        XCTAssertFalse(invocation.needsAssignment)
    }

    func testCancelRequest() {
        let invocation = HARequestInvocation(request: .init(
            type: .renderTemplate,
            data: [:]
        ))
        XCTAssertNil(invocation.cancelRequest())
        invocation.cancel()
    }

    // MARK: - Retry Timeout Tests

    func testRetryTimeoutNotExpiredWithinTimeout() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: 10.0)
        let invocation = HARequestInvocation(request: request)

        // Check immediately after creation
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check 5 seconds later (within timeout)
        HAGlobal.date = { startDate.addingTimeInterval(5.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check 9.9 seconds later (still within timeout)
        HAGlobal.date = { startDate.addingTimeInterval(9.9) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutExpiredAfterTimeout() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: 10.0)
        let invocation = HARequestInvocation(request: request)

        // Check exactly at timeout boundary
        HAGlobal.date = { startDate.addingTimeInterval(10.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired, "Should not be expired at exactly 10 seconds")

        // Check just after timeout
        HAGlobal.date = { startDate.addingTimeInterval(10.1) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired, "Should be expired after 10 seconds")

        // Check well after timeout
        HAGlobal.date = { startDate.addingTimeInterval(60.0) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired, "Should be expired after 60 seconds")
    }

    func testRetryTimeoutNeverExpiresWhenNil() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: nil)
        let invocation = HARequestInvocation(request: request)

        // Check immediately
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after 1 hour
        HAGlobal.date = { startDate.addingTimeInterval(3600.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after 1 day
        HAGlobal.date = { startDate.addingTimeInterval(86400.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutWithCustomTimeout() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: 30.0)
        let invocation = HARequestInvocation(request: request)

        // Check before timeout
        HAGlobal.date = { startDate.addingTimeInterval(20.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after timeout
        HAGlobal.date = { startDate.addingTimeInterval(31.0) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutWithVeryShortTimeout() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: 0.5)
        let invocation = HARequestInvocation(request: request)

        // Check before timeout
        HAGlobal.date = { startDate.addingTimeInterval(0.3) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after timeout
        HAGlobal.date = { startDate.addingTimeInterval(0.6) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }

    func testCreatedAtCapturesCorrectTime() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:])
        let invocation = HARequestInvocation(request: request)

        XCTAssertEqual(invocation.createdAt, startDate)

        // Change current time - createdAt should not change
        HAGlobal.date = { startDate.addingTimeInterval(100) }
        XCTAssertEqual(invocation.createdAt, startDate)
    }

    func testDefaultRetryTimeoutIsApplied() {
        let request = HARequest(type: .callService, data: [:])
        XCTAssertEqual(request.retryTimeout, 10.0, "Default retry timeout should be 10 seconds")
    }

    func testRetryTimeoutCanBeSetToZero() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:], retryTimeout: 0.0)
        let invocation = HARequestInvocation(request: request)

        // Should expire immediately
        HAGlobal.date = { startDate.addingTimeInterval(0.001) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }
}
