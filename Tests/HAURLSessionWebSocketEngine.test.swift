@testable import HAKit
import Starscream
import XCTest

internal class HAURLSessionWebSocketEngineTests: XCTestCase {
    func testClientCertificateChallengeUsesIdentity() throws {
        let identity = try createClientIdentity()
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { identity }, evaluateCertificate: nil)
        let session = URLSession(configuration: .ephemeral)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)

        let handled = expectation(description: "client certificate provided")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .useCredential)
            XCTAssertNotNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testClientCertificateChallengeWithoutIdentityUsesDefault() {
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        let session = URLSession(configuration: .ephemeral)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)

        let handled = expectation(description: "default handling without identity")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testServerTrustChallengeSucceedsWhenEvaluationSucceeds() throws {
        let engine = HAURLSessionWebSocketEngine(
            clientIdentity: { nil },
            evaluateCertificate: { $1(.success(())) }
        )
        let session = URLSession(configuration: .ephemeral)
        let challenge = try makeServerTrustChallenge()

        let handled = expectation(description: "server trust accepted")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .useCredential)
            XCTAssertNotNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testServerTrustChallengeCancelsWhenEvaluationFails() throws {
        let engine = HAURLSessionWebSocketEngine(
            clientIdentity: { nil },
            evaluateCertificate: { $1(.failure(TestError.rejected)) }
        )
        let session = URLSession(configuration: .ephemeral)
        let challenge = try makeServerTrustChallenge()

        let handled = expectation(description: "server trust rejected")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge)
            XCTAssertNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testServerTrustChallengeUsesDefaultWithoutEvaluator() throws {
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        let session = URLSession(configuration: .ephemeral)
        let challenge = try makeServerTrustChallenge()

        let handled = expectation(description: "server trust default handling")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testServerTrustChallengeUsesDefaultWithoutTrust() {
        let engine = HAURLSessionWebSocketEngine(
            clientIdentity: { nil },
            evaluateCertificate: { $1(.success(())) }
        )
        let session = URLSession(configuration: .ephemeral)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust)

        let handled = expectation(description: "server trust default handling without trust")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testDefaultAuthenticationChallengeUsesDefault() {
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        let session = URLSession(configuration: .ephemeral)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic)

        let handled = expectation(description: "default challenge handling")
        engine.urlSession(session, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            handled.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testDelegateCallbacksBroadcastEvents() throws {
        let delegate = MockEngineDelegate()
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        engine.register(delegate: delegate)

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = try session.webSocketTask(with: XCTUnwrap(URL(string: "wss://example.com/api/websocket")))
        task.cancel(with: .normalClosure, reason: nil)

        engine.urlSession(session, webSocketTask: task, didOpenWithProtocol: "chat")
        engine.urlSession(session, webSocketTask: task, didCloseWith: .goingAway, reason: Data("bye".utf8))
        engine.urlSession(session, task: task, didCompleteWithError: URLError(.timedOut))

        XCTAssertTrue(delegate.events.contains { if case .connected = $0 { return true } else { return false } })
        XCTAssertTrue(delegate.events.contains { if case .disconnected = $0 { return true } else { return false } })
        XCTAssertTrue(delegate.events.contains { if case .error = $0 { return true } else { return false } })
    }

    func testStartWritesAndStop() throws {
        let delegate = MockEngineDelegate()
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        engine.register(delegate: delegate)

        let errored = expectation(description: "read fails once the socket is cancelled")
        errored.assertForOverFulfill = false
        delegate.onEvent = { event in
            if case .error = event { errored.fulfill() }
        }

        let request = try URLRequest(url: XCTUnwrap(URL(string: "wss://127.0.0.1:1/api/websocket")))
        engine.start(request: request)
        engine.write(string: "text", completion: nil)
        engine.write(data: Data("binary".utf8), opcode: .binaryFrame, completion: nil)
        engine.write(data: Data("as-text".utf8), opcode: .textFrame, completion: nil)
        engine.write(data: Data(), opcode: .ping, completion: nil)
        engine.write(data: Data(), opcode: .pong, completion: nil)
        engine.stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.normalClosure.rawValue))
        engine.forceStop()

        wait(for: [errored], timeout: 10)
    }

    func testSendCompletionInvokesCompletion() {
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)

        var called = false
        engine.sendCompletion { called = true }(nil)
        XCTAssertTrue(called)

        engine.sendCompletion(nil)(nil)
    }

    func testHandleReceiveResultBroadcastsMessages() {
        let delegate = MockEngineDelegate()
        let engine = HAURLSessionWebSocketEngine(clientIdentity: { nil }, evaluateCertificate: nil)
        engine.register(delegate: delegate)

        engine.handleReceiveResult(.success(.string("hello")))
        engine.handleReceiveResult(.success(.data(Data("bytes".utf8))))
        engine.handleReceiveResult(.failure(URLError(.badServerResponse)))

        XCTAssertTrue(delegate.events.contains { if case .text("hello") = $0 { return true } else { return false } })
        XCTAssertTrue(delegate.events.contains { if case .binary = $0 { return true } else { return false } })
        XCTAssertTrue(delegate.events.contains { if case .error = $0 { return true } else { return false } })
    }

    // MARK: - Helpers

    private enum TestError: Error {
        case rejected
    }

    private func makeChallenge(authenticationMethod: String) -> URLAuthenticationChallenge {
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: authenticationMethod
        )
        return URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockChallengeSender()
        )
    }

    private func makeServerTrustChallenge() throws -> URLAuthenticationChallenge {
        let protectionSpace = try TrustProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust,
            serverTrust: createServerTrust()
        )
        return URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockChallengeSender()
        )
    }

    private func createClientIdentity() throws -> SecIdentity {
        let data = try XCTUnwrap(Data(base64Encoded: Self.identityP12Base64, options: [.ignoreUnknownCharacters]))
        let options = [kSecImportExportPassphrase as String: "hakittest"] as CFDictionary
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options, &items)
        XCTAssertEqual(status, errSecSuccess)
        let entries = try XCTUnwrap(items as? [[String: Any]])
        let entry = try XCTUnwrap(entries.first)
        let value = try XCTUnwrap(entry[kSecImportItemIdentity as String])
        // swiftlint:disable:next force_cast
        return value as! SecIdentity
    }

    private func createServerTrust() throws -> SecTrust {
        let certData = try XCTUnwrap(Data(base64Encoded: Self.certificateBase64, options: [.ignoreUnknownCharacters]))
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, certData as CFData))
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
        XCTAssertEqual(status, errSecSuccess)
        return try XCTUnwrap(trust)
    }
}

// MARK: - Test Doubles

private final class MockEngineDelegate: EngineDelegate {
    private(set) var events: [WebSocketEvent] = []
    var onEvent: ((WebSocketEvent) -> Void)?

    func didReceive(event: WebSocketEvent) {
        events.append(event)
        onEvent?(event)
    }
}

private final class MockChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}

private final class TrustProtectionSpace: URLProtectionSpace, @unchecked Sendable {
    private let trust: SecTrust?

    init(
        host: String,
        port: Int,
        protocol: String?,
        realm: String?,
        authenticationMethod: String,
        serverTrust: SecTrust?
    ) {
        self.trust = serverTrust
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
        trust
    }
}

// MARK: - Fixtures

private extension HAURLSessionWebSocketEngineTests {
    static let identityP12Base64 = """
    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
    8lXW6bhLIQICCAA=
    """

    static let certificateBase64 = """
    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
    """
}
