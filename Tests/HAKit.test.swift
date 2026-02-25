@testable import HAKit
import XCTest

internal class HAKitTests: XCTestCase {
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
    
    func testCreationWithCustomURLSession() {
        let configuration = HAConnectionConfiguration.test
        let customSession = URLSession(configuration: .ephemeral)
        let connection = HAKit.connection(
            configuration: configuration,
            urlSession: customSession
        )
        
        XCTAssertEqual(connection.configuration.connectionInfo(), configuration.connectionInfo())
        
        // Verify the connection was created successfully with the custom session
        let expectation = self.expectation(description: "access token with custom session")
        connection.configuration.fetchAuthToken { connectionValue in
            configuration.fetchAuthToken { testValue in
                XCTAssertEqual(try? connectionValue.get(), try? testValue.get())
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0)
    }
    
    func testCreationWithDefaultURLSession() {
        let configuration = HAConnectionConfiguration.test
        // Test that passing nil uses the default ephemeral session
        let connection = HAKit.connection(
            configuration: configuration,
            urlSession: nil
        )
        
        XCTAssertEqual(connection.configuration.connectionInfo(), configuration.connectionInfo())
    }
    
    func testCreationWithCustomDelegateSession() {
        // Mock certificate provider for testing
        final class TestCertificateProvider: HACertificateProvider {
            func provideClientCertificate(
                for challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
            ) {
                completionHandler(.useCredential, nil)
            }
            
            func evaluateServerTrust(
                _ serverTrust: SecTrust,
                forHost host: String,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
            ) {
                completionHandler(.useCredential, nil)
            }
        }
        
        let configuration = HAConnectionConfiguration.test
        let provider = TestCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        let customSession = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        
        let connection = HAKit.connection(
            configuration: configuration,
            urlSession: customSession
        )
        
        XCTAssertEqual(connection.configuration.connectionInfo(), configuration.connectionInfo())
        
        // Verify that the connection can be used normally
        let expectation = self.expectation(description: "access token with delegate session")
        connection.configuration.fetchAuthToken { result in
            if case let .success(token) = result {
                XCTAssertNotNil(token)
            } else {
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0)
    }
}
