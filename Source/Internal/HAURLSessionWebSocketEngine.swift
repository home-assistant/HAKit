import Foundation

/// An ``HAWebSocketEngine`` backed by `URLSessionWebSocketTask`.
///
/// The URL Loading System supports modern TLS versions and presents the client certificate through
/// the standard authentication challenge, the same path the REST API uses. It handles server trust
/// evaluation and client-identity (mTLS) challenges, so it serves every connection whether or not a
/// client identity is provided.
internal final class HAURLSessionWebSocketEngine: NSObject, HAWebSocketEngine, URLSessionDataDelegate,
    URLSessionWebSocketDelegate {
    /// Home Assistant can deliver large frames (e.g. full state dumps). Raise the receive limit well
    /// above `URLSessionWebSocketTask`'s 1 MiB default so those frames aren't rejected.
    private static let maximumMessageSize = 100 * 1024 * 1024

    private struct State {
        var session: URLSession?
        var task: URLSessionWebSocketTask?
    }

    /// `session`/`task` are read on the queue that calls `write` (a background work queue) and on the
    /// `URLSession` delegate queue, and mutated on the main queue by `start`/`stop`, so all access goes
    /// through this lock.
    private let state = HAProtected<State>(value: .init())
    private weak var delegate: HAWebSocketEngineDelegate?

    private let clientIdentity: HAConnectionInfo.ClientIdentityProvider?
    private let evaluateCertificate: HAConnectionInfo.EvaluateCertificate?

    init(
        clientIdentity: HAConnectionInfo.ClientIdentityProvider?,
        evaluateCertificate: HAConnectionInfo.EvaluateCertificate?
    ) {
        self.clientIdentity = clientIdentity
        self.evaluateCertificate = evaluateCertificate
        super.init()
    }

    func register(delegate: HAWebSocketEngineDelegate) {
        self.delegate = delegate
    }

    func start(request: URLRequest) {
        let task: URLSessionWebSocketTask = state.mutate { state in
            let session = state.session ?? URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            state.session = session
            let task = session.webSocketTask(with: request)
            task.maximumMessageSize = Self.maximumMessageSize
            state.task = task
            return task
        }
        doRead()
        task.resume()
    }

    func stop(closeCode: UInt16) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
        let (task, session) = takeState()
        task?.cancel(with: closeCode, reason: nil)
        // Invalidating releases the `URLSession`'s strong reference to this engine (its delegate),
        // breaking the retain cycle; sessions are never reused (`start` creates a fresh one).
        session?.finishTasksAndInvalidate()
    }

    func forceStop() {
        let (task, session) = takeState()
        task?.cancel(with: .abnormalClosure, reason: nil)
        session?.invalidateAndCancel()
    }

    /// Atomically clear and return the current task and session.
    private func takeState() -> (URLSessionWebSocketTask?, URLSession?) {
        state.mutate { state in
            defer { state = .init() }
            return (state.task, state.session)
        }
    }

    func write(string: String, completion: (() -> Void)?) {
        let task = state.read { $0.task }
        task?.send(.string(string), completionHandler: sendCompletion(completion))
    }

    func write(data: Data, opcode: HAFrameOpCode, completion: (() -> Void)?) {
        switch opcode {
        case .binaryFrame:
            let task = state.read { $0.task }
            task?.send(.data(data), completionHandler: sendCompletion(completion))
        case .textFrame:
            write(string: String(decoding: data, as: UTF8.self), completion: completion)
        case .ping:
            let task = state.read { $0.task }
            task?.sendPing(pongReceiveHandler: sendCompletion(completion))
        default:
            break
        }
    }

    func sendCompletion(_ completion: (() -> Void)?) -> (Error?) -> Void {
        { _ in completion?() }
    }

    private func doRead() {
        let task = state.read { $0.task }
        task?.receive { [weak self] result in
            self?.handleReceiveResult(result)
        }
    }

    func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case let .success(message):
            if case let .string(string) = message {
                broadcast(event: .text(string))
            } else if case let .data(data) = message {
                broadcast(event: .binary(data))
            }
            doRead()
        case let .failure(error):
            broadcast(event: .error(error))
        }
    }

    private func broadcast(event: HAWebSocketEvent) {
        delegate?.didReceive(event: event)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        broadcast(event: .connected(["Sec-WebSocket-Protocol": `protocol` ?? ""]))
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        broadcast(event: .disconnected(reasonString, UInt16(closeCode.rawValue)))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        broadcast(event: .error(error))
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            if let identity = clientIdentity?() {
                completionHandler(
                    .useCredential,
                    URLCredential(identity: identity, certificates: nil, persistence: .forSession)
                )
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        case NSURLAuthenticationMethodServerTrust:
            guard let evaluateCertificate, let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            evaluateCertificate(serverTrust) { result in
                switch result {
                case .success:
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                case .failure:
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
