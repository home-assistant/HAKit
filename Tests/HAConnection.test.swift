@testable import HAWebSocket
import XCTest

internal class HAConnectionTests: XCTestCase {
    func testSingletonClass() {
        XCTAssertTrue(HAConnection.API === HAConnectionImpl.self)
    }

    func testCreation() {
        let configuration = HAConnectionConfiguration.test
        let connection = HAConnection.api(configuration: configuration)
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
