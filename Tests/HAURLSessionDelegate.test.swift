@testable import HAKit
import XCTest

internal class HAURLSessionDelegateTests: XCTestCase {
    /// Mock implementation of HACertificateProvider for testing
    private final class MockCertificateProvider: HACertificateProvider {
        var provideClientCertificateCalled = false
        var evaluateServerTrustCalled = false
        var clientCertificateDisposition: URLSession.AuthChallengeDisposition = .useCredential
        var clientCertificateCredential: URLCredential?
        var serverTrustDisposition: URLSession.AuthChallengeDisposition = .useCredential
        var serverTrustCredential: URLCredential?
        
        func provideClientCertificate(
            for challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            provideClientCertificateCalled = true
            completionHandler(clientCertificateDisposition, clientCertificateCredential)
        }
        
        func evaluateServerTrust(
            _ serverTrust: SecTrust,
            forHost host: String,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            evaluateServerTrustCalled = true
            completionHandler(serverTrustDisposition, serverTrustCredential)
        }
    }
    
    func testInitialization() {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        
        XCTAssertNotNil(delegate)
    }
    
    func testClientCertificateChallenge() {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        
        // Create a mock URLSession
        let session = URLSession(configuration: .ephemeral)
        
        // Create a mock protection space for client certificate
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodClientCertificate
        )
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )
        
        let expectation = self.expectation(description: "Client certificate challenge handled")
        
        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertTrue(provider.provideClientCertificateCalled)
            XCTAssertEqual(disposition, .useCredential)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testServerTrustChallengeWithoutTrust() {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        
        let session = URLSession(configuration: .ephemeral)
        
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust
        )
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )
        
        let expectation = self.expectation(description: "Server trust challenge handled with default")
        
        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            // Should use default handling when serverTrust is nil
            XCTAssertFalse(provider.evaluateServerTrustCalled)
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testDefaultAuthenticationChallenge() {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        
        let session = URLSession(configuration: .ephemeral)
        
        // Use a different authentication method (e.g., basic auth)
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: "Protected",
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )
        
        let expectation = self.expectation(description: "Default challenge handled")
        
        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertFalse(provider.provideClientCertificateCalled)
            XCTAssertFalse(provider.evaluateServerTrustCalled)
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testProviderRejectsClientCertificate() {
        let provider = MockCertificateProvider()
        provider.clientCertificateDisposition = .cancelAuthenticationChallenge
        provider.clientCertificateCredential = nil
        
        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        let session = URLSession(configuration: .ephemeral)
        
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodClientCertificate
        )
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )
        
        let expectation = self.expectation(description: "Client certificate rejection handled")
        
        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge)
            XCTAssertNil(credential)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // Note: Tests for server trust validation with actual SecTrust objects are
    // difficult to implement in unit tests as creating valid SecTrust objects
    // requires real certificates. These scenarios are better tested through
    // integration tests or manual testing with actual mTLS setups.
}

// MARK: - Mock Classes

/// Mock URLAuthenticationChallengeSender for testing
private class MockURLAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}
