@testable import HAKit
import XCTest

internal class HARequestInvocationSingleTests: XCTestCase {
    func testCancelRequest() {
        let invocation = HARequestInvocationSingle(
            request: .init(type: .callService, data: [:]),
            completion: { _ in }
        )
        XCTAssertNil(invocation.cancelRequest())
    }

    func testNeedsAssignmentBySending() {
        let invocation = HARequestInvocationSingle(
            request: .init(type: .callService, data: [:]),
            completion: { _ in }
        )
        XCTAssertTrue(invocation.needsAssignment)
        invocation.identifier = 44
        XCTAssertFalse(invocation.needsAssignment)
    }

    func testNeedsAssignmentByCanceling() {
        class TestClass {}
        var value: TestClass? = TestClass()
        weak var weakValue = value
        XCTAssertNotNil(weakValue)

        let invocation = HARequestInvocationSingle(
            request: .init(type: .callService, data: [:]),
            completion: { [value] _ in withExtendedLifetime(value) {} }
        )
        XCTAssertTrue(invocation.needsAssignment)
        invocation.cancel()
        XCTAssertFalse(invocation.needsAssignment)

        value = nil
        XCTAssertNil(weakValue)
    }

    func testCompletionInvokedOnceAndCleared() throws {
        let completionExpectation = expectation(description: "completion")

        class TestClass {}
        var value: TestClass? = TestClass()
        weak var weakValue = value
        XCTAssertNotNil(weakValue)

        let invocation = HARequestInvocationSingle(
            request: .init(type: .callService, data: [:]),
            completion: { [value] result in
                switch result {
                case .success(.empty): break
                default: XCTFail("expected .success(empty), got \(result)")
                }

                withExtendedLifetime(value) {
                    completionExpectation.fulfill()
                }
            }
        )

        value = nil
        XCTAssertNotNil(weakValue)

        invocation.resolve(.success(.empty))
        waitForExpectations(timeout: 10.0)
        XCTAssertNil(weakValue)
    }
}
