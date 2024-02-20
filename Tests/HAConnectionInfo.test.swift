@testable import HAKit
import Starscream
import XCTest

internal class HAConnectionInfoTests: XCTestCase {
    func testCreation() throws {
        let url1 = URL(string: "http://example.com")!
        let url2 = URL(string: "http://example.com/2")!

        let connectionInfo1 = try HAConnectionInfo(url: url1)
        XCTAssertEqual(connectionInfo1.url, url1)
        XCTAssertEqual(connectionInfo1, connectionInfo1)

        let connectionInfo2 = try HAConnectionInfo(url: url1)
        XCTAssertEqual(connectionInfo1, connectionInfo2)

        let connectionInfo3 = try HAConnectionInfo(url: url2)
        XCTAssertEqual(connectionInfo3, connectionInfo3)

        XCTAssertNotEqual(connectionInfo1, connectionInfo3)
        XCTAssertNotEqual(connectionInfo2, connectionInfo3)

        let webSocket1 = connectionInfo1.webSocket()
        let webSocket2 = connectionInfo3.webSocket()
        XCTAssertNil(webSocket1.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket2.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertEqual(webSocket1.request.value(forHTTPHeaderField: "Host"), "example.com")
        XCTAssertEqual(webSocket1.request.url, url1.appendingPathComponent("api/websocket"))
        XCTAssertEqual(webSocket2.request.url, url2.appendingPathComponent("api/websocket"))
    }

    func testCreationWithEngine() throws {
        let url = URL(string: "http://example.com/with_engine")!
        let engine1 = FakeEngine()
        let engine2 = FakeEngine()

        let connectionInfo = try HAConnectionInfo(
            url: url,
            userAgent: nil,
            evaluateCertificate: nil,
            engine: engine1,
            customHeaders: nil
        )
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(ObjectIdentifier(connectionInfo.engine as AnyObject), ObjectIdentifier(engine1))

        let webSocket = connectionInfo.webSocket()
        XCTAssertNil(webSocket.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "Host"), "example.com")

        webSocket.write(string: "test")
        XCTAssertTrue(engine1.events.contains(.writeString("test")))

        let connectionInfoWithoutEngine = try HAConnectionInfo(url: url)
        // just engine difference isn't enough (since we can't tell)
        XCTAssertFalse(connectionInfoWithoutEngine.shouldReplace(webSocket))

        let connectionInfoWithDifferentEngine = try HAConnectionInfo(
            url: url,
            userAgent: nil,
            evaluateCertificate: nil,
            engine: engine2,
            customHeaders: nil
        )
        XCTAssertFalse(connectionInfoWithDifferentEngine.shouldReplace(webSocket))
    }

    func testCreationWithUserAgent() throws {
        let url = URL(string: "http://example.com/with_user_agent")!
        let userAgent = "SomeAgent/1.0"

        let connectionInfo = try HAConnectionInfo(url: url, userAgent: userAgent)
        XCTAssertEqual(connectionInfo.url, url)
        XCTAssertEqual(connectionInfo.userAgent, userAgent)

        let webSocket = connectionInfo.webSocket()
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "User-Agent"), userAgent)
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "Host"), "example.com")
    }

    func testCreationWithNonstandardPort() throws {
        let url1 = URL(string: "http://example.com:12345/with_porty_host")!
        let url2 = URL(string: "http://example.com:80/with_porty_host")!
        let url3 = URL(string: "https://example.com:443/with_porty_host")!

        let connectionInfo1 = try HAConnectionInfo(url: url1)
        let connectionInfo2 = try HAConnectionInfo(url: url2)
        let connectionInfo3 = try HAConnectionInfo(url: url3)
        XCTAssertEqual(connectionInfo1.url, url1)
        XCTAssertEqual(connectionInfo2.url, url2)
        XCTAssertEqual(connectionInfo3.url, url3)

        let webSocket1 = connectionInfo1.webSocket()
        let webSocket2 = connectionInfo2.webSocket()
        let webSocket3 = connectionInfo3.webSocket()
        XCTAssertNil(webSocket1.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket2.request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(webSocket3.request.value(forHTTPHeaderField: "User-Agent"))

        XCTAssertEqual(webSocket1.request.value(forHTTPHeaderField: "Host"), "example.com:12345")
        XCTAssertEqual(webSocket2.request.value(forHTTPHeaderField: "Host"), "example.com")
        XCTAssertEqual(webSocket3.request.value(forHTTPHeaderField: "Host"), "example.com")
    }

    func testCreationWithInvalidURL() throws {
        var components1 = URLComponents()
        components1.scheme = "http"
        components1.host = ""
        components1.port = 80

        let url1 = try XCTUnwrap(components1.url)
        XCTAssertThrowsError(try HAConnectionInfo(url: url1)) { error in
            XCTAssertEqual(error as? HAConnectionInfo.CreationError, .emptyHostname)
        }

        for port in [
            String(Int(UInt16.max) + 1),
            "999999999999999",
        ] {
            let url2 = URL(string: "http://example.com:" + port)!
            XCTAssertThrowsError(try HAConnectionInfo(url: url2)) { error in
                XCTAssertEqual(error as? HAConnectionInfo.CreationError, .invalidPort)
            }
        }
    }

    func testCreationWithCertificateEvaluation() throws {
        var result: Result<Void, Error> = .success(())

        let url = URL(string: "http://example.com")!
        let connectionInfo = try HAConnectionInfo(url: url, evaluateCertificate: {
            $1(result)
        })
        XCTAssertEqual(connectionInfo.url, url)

        // not easy to test WebSocket, so we test our wrapper for it
        let pinning = HAStarscreamCertificatePinningImpl(
            evaluateCertificate: try XCTUnwrap(connectionInfo.evaluateCertificate)
        )

        var secTrust: SecTrust?
        SecTrustCreateWithCertificates([
            try XCTUnwrap(SecCertificateCreateWithData(nil, XCTUnwrap(Data(base64Encoded: """
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
            """, options: [.ignoreUnknownCharacters])) as CFData)),
        ] as CFArray, SecPolicyCreateBasicX509(), &secTrust)
        guard let secTrust = secTrust else {
            XCTFail("couldn't construct certificate")
            return
        }

        let expectation1 = expectation(description: "first request")
        pinning.evaluateTrust(trust: secTrust, domain: "some_domain") { pinningState in
            switch pinningState {
            case .success:
                // pass
                break
            case .failed:
                XCTFail("expected success, got failure")
            }
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 10.0)

        enum TestError: Error {
            case any
        }
        result = .failure(TestError.any)

        let expectation2 = expectation(description: "second request")
        pinning.evaluateTrust(trust: secTrust, domain: "some_domain") { pinningState in
            switch pinningState {
            case .success:
                XCTFail("expected failure, got success")
            case .failed:
                // pass
                break
            }
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 10.0)
    }

    func testShouldReplace() throws {
        let url1 = URL(string: "http://example.com/1")!
        let url2 = URL(string: "http://example.com/2")!
        let engine = FakeEngine()

        let connectionInfo1 = try HAConnectionInfo(
            url: url1,
            userAgent: nil,
            evaluateCertificate: nil,
            engine: engine,
            customHeaders: nil
        )
        let connectionInfo2 = try HAConnectionInfo(
            url: url2,
            userAgent: nil,
            evaluateCertificate: nil,
            engine: engine,
            customHeaders: nil
        )

        let webSocket1 = connectionInfo1.webSocket()
        XCTAssertFalse(connectionInfo1.shouldReplace(webSocket1))
        XCTAssertTrue(connectionInfo2.shouldReplace(webSocket1))
    }

    func testSanitize() throws {
        let expected = try XCTUnwrap(URL(string: "http://example.com"))

        for invalid in [
            "http://example.com",
            "http://example.com/",
            "http://example.com/////",
            "http://example.com/api",
            "http://example.com/api/",
            "http://example.com/api/websocket",
            "http://example.com/api/websocket/",
        ] {
            let url = try XCTUnwrap(URL(string: invalid))
            let connectionInfo = try HAConnectionInfo(url: url)
            XCTAssertEqual(connectionInfo.url, expected)
        }
    }

    func testCustomHeaders() throws {
        let url = URL(string: "http://example.com")!

        let customHeaders = [HAHeader(key: "key1", value: "test1"), HAHeader(key: "key2", value: "test2")]

        let connectionInfo1 = try HAConnectionInfo(url: url, customHeaders: customHeaders)
        XCTAssertEqual(connectionInfo1.customHeaders, customHeaders)
        XCTAssertEqual(connectionInfo1.customHeaders.count, customHeaders.count)

        let webSocket = connectionInfo1.webSocket()
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "key1"), "test1")
        XCTAssertEqual(webSocket.request.value(forHTTPHeaderField: "key2"), "test2")
    }

//    func testInvalidURLComponentsURL() throws {
//        // example of valid URL invalid URLComponents - https://stackoverflow.com/questions/55609012
//        let url = try XCTUnwrap(URL(string: "a://@@/api/websocket"))
//        let connectionInfo = try HAConnectionInfo(url: url)
//        XCTAssertEqual(connectionInfo.url, url)
//        XCTAssertEqual(connectionInfo.webSocket().request.url, url.appendingPathComponent("api/websocket"))
//    }
}
