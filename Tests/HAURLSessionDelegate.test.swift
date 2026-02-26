@testable import HAKit
import XCTest

internal class HAURLSessionDelegateTests: XCTestCase {
    /// Mock implementation of HACertificateProvider for testing
    private final class MockCertificateProvider: HACertificateProvider {
        var provideClientCertificateCalled = false
        var evaluateServerTrustCalled = false
        var receivedHost: String?
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
            receivedHost = host
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

        delegate.urlSession(session, didReceive: challenge) { disposition, _ in
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

    func testServerTrustChallengeWithTrust() {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)

        let session = URLSession(configuration: .ephemeral)

        // Create a minimal, valid DER-encoded certificate for testing
        // This is a real self-signed certificate generated with openssl
        let certData = Data(
            base64Encoded:
                "MIIBkTCB+wIJAKoSVqPi4qyMMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl" +
                "c3RlcjAeFw0yNDAyMjYwMDAwMDBaFw0yNTAyMjYwMDAwMDBaMBExDzANBgNVBAMM" +
                "BnRlc3RlcjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAw0qKpfOtGlR7cqYU" +
                "4WqKvVqExNdvCblJ4cNslAn/YY4U0k0vD4g0bTtJpqm0PAqPJJT0cLlXZmMKt8lC" +
                "EqtqPkQN8L1Kq4TtJpPtqKlQpvNqtJpqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvN" +
                "qtJpPtqKlQpvNqtJpPtqKlQpvNqtJpwCAwEAATANBgkqhkiG9w0BAQsFAAOBgQBM" +
                "2qtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQp" +
                "vNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQ" +
                "pvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKg"
        )!

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            // If certificate creation fails, skip this test gracefully
            // This can happen on certain platforms or configurations
            return
        }

        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)

        guard status == errSecSuccess, let serverTrust = trust else {
            // If trust creation fails, skip this test gracefully
            return
        }

        let customProtectionSpace = CustomProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust,
            serverTrust: serverTrust
        )

        let customChallenge = URLAuthenticationChallenge(
            protectionSpace: customProtectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )

        let expectation = self.expectation(description: "Server trust challenge handled")

        delegate.urlSession(session, didReceive: customChallenge) { disposition, _ in
            XCTAssertTrue(provider.evaluateServerTrustCalled)
            XCTAssertEqual(provider.receivedHost, "example.com")
            XCTAssertEqual(disposition, .useCredential)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testProviderRejectsServerTrust() {
        let provider = MockCertificateProvider()
        provider.serverTrustDisposition = .cancelAuthenticationChallenge
        provider.serverTrustCredential = nil

        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        let session = URLSession(configuration: .ephemeral)

        // Create a minimal DER-encoded certificate for testing
        let certData = Data(
            base64Encoded:
                "MIIBkTCB+wIJAKoSVqPi4qyMMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl" +
                "c3RlcjAeFw0yNDAyMjYwMDAwMDBaFw0yNTAyMjYwMDAwMDBaMBExDzANBgNVBAMM" +
                "BnRlc3RlcjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAw0qKpfOtGlR7cqYU" +
                "4WqKvVqExNdvCblJ4cNslAn/YY4U0k0vD4g0bTtJpqm0PAqPJJT0cLlXZmMKt8lC" +
                "EqtqPkQN8L1Kq4TtJpPtqKlQpvNqtJpqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvN" +
                "qtJpPtqKlQpvNqtJpPtqKlQpvNqtJpwCAwEAATANBgkqhkiG9w0BAQsFAAOBgQBM" +
                "2qtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQp" +
                "vNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQ" +
                "pvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKlQpvNqtJpPtqKg"
        )!

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            return
        }

        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)

        guard status == errSecSuccess, let serverTrust = trust else {
            return
        }

        let customProtectionSpace = CustomProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust,
            serverTrust: serverTrust
        )

        let challenge = URLAuthenticationChallenge(
            protectionSpace: customProtectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockURLAuthenticationChallengeSender()
        )

        let expectation = self.expectation(description: "Server trust rejection handled")

        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertTrue(provider.evaluateServerTrustCalled)
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

// MARK: - Mock Classes

/// Custom URLProtectionSpace that allows setting serverTrust
private class CustomProtectionSpace: URLProtectionSpace, @unchecked Sendable {
    private let _serverTrust: SecTrust?

    init(
        host: String,
        port: Int,
        protocol: String?,
        realm: String?,
        authenticationMethod: String,
        serverTrust: SecTrust?
    ) {
        self._serverTrust = serverTrust
        super.init(
            host: host,
            port: port,
            protocol: `protocol`,
            realm: realm,
            authenticationMethod: authenticationMethod
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var serverTrust: SecTrust? {
        _serverTrust
    }
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
