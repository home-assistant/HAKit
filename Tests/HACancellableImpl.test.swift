@testable import HAWebSocket
import XCTest

internal class HACancellableImplTests: XCTestCase {
    func testInvokingHandler() {
        let expectation = self.expectation(description: "invoked cancellable")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        let cancellable = HACancellableImpl(handler: {
            expectation.fulfill()
        })

        cancellable.cancel()

        // make sure invokoing it twice doesn't fire the handler twice
        cancellable.cancel()

        waitForExpectations(timeout: 10.0)
    }
}
