@testable import HAWebSocket
import XCTest

internal class HARequestInvocationSubscriptionTests: XCTestCase {
    func testCancelRequestBeforeAssigned() {
        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
        )
        XCTAssertNil(invocation.cancelRequest())
    }

    func testCancelRequestAfterAssigned() throws {
        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
        )
        invocation.identifier = 77

        let request = try XCTUnwrap(invocation.cancelRequest())
        XCTAssertEqual(request.request.type, .unsubscribeEvents)
        XCTAssertEqual(request.request.data["subscription"] as? Int, 77)
    }

    func testNeedsAssignmentBySending() {
        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { _ in },
            handler: { _, _ in }
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

        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { [value] _ in withExtendedLifetime(value) {} },
            handler: { [value] _, _ in withExtendedLifetime(value) {} }
        )
        XCTAssertTrue(invocation.needsAssignment)
        invocation.cancel()
        XCTAssertFalse(invocation.needsAssignment)

        value = nil
        XCTAssertNil(weakValue)
    }

    func testResolveHandler() {
        var resolved: Result<HAData, HAError>?

        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { resolved = $0 },
            handler: { _, _ in }
        )

        invocation.resolve(.success(.empty))

        if case .success(.empty) = resolved {
            // pass
        } else {
            XCTFail("expected success with empty, got \(String(describing: resolved))")
        }

        invocation.resolve(.failure(.internal(debugDescription: "test")))

        if case .failure(.internal(debugDescription: "test")) = resolved {
            // pass
        } else {
            XCTFail("expected failure, got \(String(describing: resolved))")
        }
    }

    func testHandler() throws {
        var invoked: (token: HACancellable, event: HAData)?

        let invocation = HARequestInvocationSubscription(
            request: .init(type: .callService, data: [:]),
            initiated: { _ in },
            handler: { invoked = (token: $0, event: $1) }
        )

        var handler1Called = false

        invocation.invoke(token: .init(handler: { handler1Called = true }), event: .init(value: ["ok": "yeah"]))

        XCTAssertFalse(handler1Called)
        invoked?.token.cancel()
        XCTAssertTrue(handler1Called)

        XCTAssertEqual(try XCTUnwrap(invoked).event.decode("ok") as String, "yeah")
    }
}
