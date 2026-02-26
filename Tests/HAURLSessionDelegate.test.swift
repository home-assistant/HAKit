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

    private func createServerTrust() throws -> SecTrust {
        let certData = try XCTUnwrap(
            Data(base64Encoded: """
                MIIFljCCA36gAwIBAgINAgO8U1lrNMcY9QFQZjANBgkqhkiG9w0BAQsFADBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRy
                dXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMjAwODEzMDAwMDQyWhcNMjcwOTMwMDAwMDQyWjBGMQswCQYD
                VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzETMBEGA1UEAxMKR1RTIENBIDFDMzCCASIwDQYJKoZIhvcN
                AQEBBQADggEPADCCAQoCggEBAPWI3+dijB43+DdCkH9sh9D7ZYIl/ejLa6T/belaI+KZ9hzpkgOZE3wJCor6QtZeViSqejOEH9Hpabu5
                dOxXTGZok3c3VVP+ORBNtzS7XyV3NzsXlOo85Z3VvMO0Q+sup0fvsEQRY9i0QYXdQTBIkxu/t/bgRQIh4JZCF8/ZK2VWNAcmBA2o/X3K
                Lu/qSHw3TT8An4Pf73WELnlXXPxXbhqW//yMmqaZviXZf5YsBvcRKgKAgOtjGDxQSYflispfGStZloEAoPtR28p3CwvJlk/vcEnHXG0g
                /Zm0tOLKLnf9LdwLtmsTDIwZKxeWmLnwi/agJ7u2441Rj72ux5uxiZ0CAwEAAaOCAYAwggF8MA4GA1UdDwEB/wQEAwIBhjAdBgNVHSUE
                FjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUinR/r4XN7pXNPZzQ4kYU83E1HScwHwYD
                VR0jBBgwFoAU5K8rJnEaK0gnhS9SZizv8IkTcT4waAYIKwYBBQUHAQEEXDBaMCYGCCsGAQUFBzABhhpodHRwOi8vb2NzcC5wa2kuZ29v
                Zy9ndHNyMTAwBggrBgEFBQcwAoYkaHR0cDovL3BraS5nb29nL3JlcG8vY2VydHMvZ3RzcjEuZGVyMDQGA1UdHwQtMCswKaAnoCWGI2h0
                dHA6Ly9jcmwucGtpLmdvb2cvZ3RzcjEvZ3RzcjEuY3JsMFcGA1UdIARQME4wOAYKKwYBBAHWeQIFAzAqMCgGCCsGAQUFBwIBFhxodHRw
                czovL3BraS5nb29nL3JlcG9zaXRvcnkvMAgGBmeBDAECATAIBgZngQwBAgIwDQYJKoZIhvcNAQELBQADggIBAIl9rCBcDDy+mqhXlRu0
                rvqrpXJxtDaV/d9AEQNMwkYUuxQkq/BQcSLbrcRuf8/xam/IgxvYzolfh2yHuKkMo5uhYpSTld9brmYZCwKWnvy15xBpPnrLRklfRuFB
                sdeYTWU0AIAaP0+fbH9JAIFTQaSSIYKCGvGjRFsqUBITTcFTNvNCCK9U+o53UxtkOCcXCb1YyRt8OS1b887U7ZfbFAO/CVMkH8IMBHmY
                JvJh8VNS/UKMG2YrPxWhu//2m+OBmgEGcYk1KCTd4b3rGS3hSMs9WYNRtHTGnXzGsYZbr8w0xNPM1IERlQCh9BIiAfq0g3GvjLeMcySs
                N1PCAJA/Ef5c7TaUEDu9Ka7ixzpiO2xj2YC/WXGsYye5TBeg2vZzFb8q3o/zpWwygTMD0IZRcZk0upONXbVRWPeyk+gB9lm+cZv9TSjO
                z23HFtz30dZGm6fKa+l3D/2gthsjgx0QGtkJAITgRNOidSOzNIb2ILCkXhAd4FJGAJ2xDx8hcFH1mt0G/FX0Kw4zd8NLQsLxdxP8c4CU
                6x+7Nz/OAipmsHMdMqUybDKwjuDEI/9bfU1lcKwrmz3O2+BtjjKAvpafkmO8l7tdufThcV4q5O8DIrGKZTqPwJNl1IXNDw9bg1kWRxYt
                nCQ6yICmJhSFm/Y3m6xv+cXDBlHz4n/FsRC6UfTd
            """, options: [.ignoreUnknownCharacters])
        )
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, certData as CFData))
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
        XCTAssertEqual(status, errSecSuccess)
        return try XCTUnwrap(trust)
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

    func testServerTrustChallengeWithTrust() throws {
        let provider = MockCertificateProvider()
        let delegate = HAURLSessionDelegate(certificateProvider: provider)

        let session = URLSession(configuration: .ephemeral)
        let serverTrust = try createServerTrust()

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

    func testProviderRejectsServerTrust() throws {
        let provider = MockCertificateProvider()
        provider.serverTrustDisposition = .cancelAuthenticationChallenge
        provider.serverTrustCredential = nil

        let delegate = HAURLSessionDelegate(certificateProvider: provider)
        let session = URLSession(configuration: .ephemeral)
        let serverTrust = try createServerTrust()

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
