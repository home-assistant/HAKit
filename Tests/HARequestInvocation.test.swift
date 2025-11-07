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

    func testRetryTimeoutNotExpiredBeforeMaximumDate() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 10, unit: .seconds))
        let invocation = HARequestInvocation(request: request)

        // Check immediately (before duration expires)
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check 5 seconds later (still before duration expires)
        HAGlobal.date = { currentDate.addingTimeInterval(5.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check 9.9 seconds later (still before duration expires)
        HAGlobal.date = { currentDate.addingTimeInterval(9.9) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check exactly at duration boundary (should not be expired)
        HAGlobal.date = { currentDate.addingTimeInterval(10.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired, "Should not be expired at exactly the duration")
    }

    func testRetryTimeoutExpiredAfterMaximumDate() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 10, unit: .seconds))
        let invocation = HARequestInvocation(request: request)

        // Check just after duration
        HAGlobal.date = { currentDate.addingTimeInterval(10.1) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired, "Should be expired after duration")

        // Check well after duration
        HAGlobal.date = { currentDate.addingTimeInterval(60.0) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired, "Should be expired after duration")
    }

    func testRetryTimeoutNeverExpiresWhenNil() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:], retryDuration: nil)
        let invocation = HARequestInvocation(request: request)

        // Check immediately
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after 1 hour
        HAGlobal.date = { currentDate.addingTimeInterval(3600.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after 1 day
        HAGlobal.date = { currentDate.addingTimeInterval(86400.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutWithCustomMaximumDate() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 30, unit: .seconds))
        let invocation = HARequestInvocation(request: request)

        // Check before duration
        HAGlobal.date = { currentDate.addingTimeInterval(20.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after duration
        HAGlobal.date = { currentDate.addingTimeInterval(31.0) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutWithVeryShortDuration() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 500, unit: .milliseconds))
        let invocation = HARequestInvocation(request: request)

        // Check before duration
        HAGlobal.date = { currentDate.addingTimeInterval(0.3) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired)

        // Check after duration
        HAGlobal.date = { currentDate.addingTimeInterval(0.6) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }

    func testDefaultRetryMaximumDateIsApplied() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        let request = HARequest(type: .callService, data: [:])

        // Default should be 10 seconds
        let expectedDuration = Measurement<UnitDuration>(value: 10, unit: .seconds)
        XCTAssertEqual(request.retryDuration, expectedDuration, "Default retry duration should be 10 seconds")
    }

    func testRetryTimeoutWithImmediateExpiry() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        // Duration of 0 seconds
        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 0, unit: .seconds))
        let invocation = HARequestInvocation(request: request)

        // Should already be expired after any time passes
        HAGlobal.date = { currentDate.addingTimeInterval(0.001) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired)
    }

    func testRetryTimeoutWithDifferentUnits() {
        let currentDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { currentDate }

        // Test with minutes
        let request1 = HARequest(type: .callService, data: [:], retryDuration: .init(value: 1, unit: .minutes))
        let invocation1 = HARequestInvocation(request: request1)

        HAGlobal.date = { currentDate.addingTimeInterval(59.0) }
        XCTAssertFalse(invocation1.isRetryTimeoutExpired, "Should not expire before 1 minute")

        HAGlobal.date = { currentDate.addingTimeInterval(61.0) }
        XCTAssertTrue(invocation1.isRetryTimeoutExpired, "Should expire after 1 minute")

        // Test with hours
        HAGlobal.date = { currentDate }
        let request2 = HARequest(type: .callService, data: [:], retryDuration: .init(value: 1, unit: .hours))
        let invocation2 = HARequestInvocation(request: request2)

        HAGlobal.date = { currentDate.addingTimeInterval(3599.0) }
        XCTAssertFalse(invocation2.isRetryTimeoutExpired, "Should not expire before 1 hour")

        HAGlobal.date = { currentDate.addingTimeInterval(3601.0) }
        XCTAssertTrue(invocation2.isRetryTimeoutExpired, "Should expire after 1 hour")
    }

    func testCreatedAtCapturesCorrectTime() {
        let startDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { startDate }

        let request = HARequest(type: .callService, data: [:])
        let invocation = HARequestInvocation(request: request)

        XCTAssertEqual(invocation.createdAt, startDate, "Invocation createdAt should capture when it was created")

        // Change current time - createdAt should not change
        HAGlobal.date = { startDate.addingTimeInterval(100) }
        XCTAssertEqual(invocation.createdAt, startDate, "Invocation createdAt should not change")
    }

    func testRetryDurationStartsWhenInvocationIsCreated() {
        let requestCreationDate = Date(timeIntervalSince1970: 1000)
        HAGlobal.date = { requestCreationDate }

        // Create request early
        let request = HARequest(type: .callService, data: [:], retryDuration: .init(value: 10, unit: .seconds))

        // Move time forward by 5 seconds before creating invocation
        let invocationCreationDate = requestCreationDate.addingTimeInterval(5.0)
        HAGlobal.date = { invocationCreationDate }

        // Create invocation (this is when it's actually executed)
        let invocation = HARequestInvocation(request: request)

        // The timeout should be based on invocation creation, not request creation
        // We're at 5 seconds after request creation, but 0 seconds after invocation creation
        XCTAssertFalse(invocation.isRetryTimeoutExpired, "Should not be expired immediately after invocation creation")

        // Move time forward by 5 more seconds (10 seconds total since request creation, 5 since invocation)
        HAGlobal.date = { requestCreationDate.addingTimeInterval(10.0) }
        XCTAssertFalse(invocation.isRetryTimeoutExpired, "Should not be expired 5 seconds after invocation creation")

        // Move time forward by 6 more seconds (16 seconds total since request creation, 11 since invocation)
        HAGlobal.date = { requestCreationDate.addingTimeInterval(16.0) }
        XCTAssertTrue(invocation.isRetryTimeoutExpired, "Should be expired 11 seconds after invocation creation")
    }
}
