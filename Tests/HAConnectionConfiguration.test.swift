@testable import HAWebSocket
import XCTest

internal class HAConnectionConfigurationTests: XCTestCase {
    func testConnectionInfo() {
        let url1 = URL(string: "http://example.com/1")!
        let url2 = URL(string: "http://example.com/2")!

        var configuration = HAConnectionConfiguration(
            connectionInfo: { .init(url: url1) },
            fetchAuthToken: { _ in fatalError() }
        )

        XCTAssertEqual(configuration.connectionInfo().url, url1)

        configuration.connectionInfo = { .init(url: url2) }
        XCTAssertEqual(configuration.connectionInfo().url, url2)
    }

    func testFetchAuthToken() throws {
        enum TestError: Error {
            case test
        }

        let string1 = "string1"
        let string2 = "string2"
        let error1 = TestError.test

        var configuration = HAConnectionConfiguration(
            connectionInfo: { fatalError() },
            fetchAuthToken: { $0(.success(string1)) }
        )

        let expectation1 = expectation(description: "string1")

        configuration.fetchAuthToken { result in
            XCTAssertEqual(try? result.get(), string1)
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: 10.0)

        let expectation2 = expectation(description: "string2")
        configuration.fetchAuthToken = { $0(.success(string2)) }
        configuration.fetchAuthToken { result in
            XCTAssertEqual(try? result.get(), string2)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 10.0)

        let expectation3 = expectation(description: "error1")
        configuration.fetchAuthToken = { $0(.failure(error1)) }
        configuration.fetchAuthToken { result in
            switch result {
            case .success: XCTFail("encountered success when expecting error")
            case let .failure(error):
                XCTAssertEqual(error as? TestError, error1)
            }
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 10.0)
    }
}
