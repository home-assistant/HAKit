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
}
