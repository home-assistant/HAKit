@testable import HAKit
import XCTest

internal class HAConnectionTests: XCTestCase {
    func testCreation() {
        let configuration = HAConnectionConfiguration.test
        let connection = HAKit.connection(configuration: configuration)
        XCTAssertEqual(connection.configuration.connectionInfo(), configuration.connectionInfo())

        let expectation = self.expectation(description: "access token")
        connection.configuration.fetchAuthToken { connectionValue in
            configuration.fetchAuthToken { testValue in
                XCTAssertEqual(try? connectionValue.get(), try? testValue.get())
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }
}
