import Foundation
import Starscream

/// A Starscream `Engine` backed by `URLSessionWebSocketTask`, used for mTLS connections.
///
/// The URL Loading System supports modern TLS versions and presents the client certificate through
/// the standard authentication challenge, the same path the REST API uses.
internal final class HAURLSessionWebSocketEngine: NSObject, Engine, URLSessionDataDelegate,
    URLSessionWebSocketDelegate {
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private weak var delegate: EngineDelegate?

    private let clientIdentity: HAConnectionInfo.ClientIdentityProvider?
    private let evaluateCertificate: HAConnectionInfo.EvaluateCertificate?
    private let cookieStorage: HTTPCookieStorage?

    init(
        clientIdentity: HAConnectionInfo.ClientIdentityProvider?,
        evaluateCertificate: HAConnectionInfo.EvaluateCertificate?,
        cookieStorage: HTTPCookieStorage? = nil
    ) {
        self.clientIdentity = clientIdentity
        self.evaluateCertificate = evaluateCertificate
        self.cookieStorage = cookieStorage
        super.init()
    }

    func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }

    func start(request: URLRequest) {
        if session == nil {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = cookieStorage
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
        task = session?.webSocketTask(with: request)
        doRead()
        task?.resume()
    }

    func stop(closeCode: UInt16) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
        task?.cancel(with: closeCode, reason: nil)
    }

    func forceStop() {
        stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
    }

    func write(string: String, completion: (() -> Void)?) {
        task?.send(.string(string), completionHandler: sendCompletion(completion))
    }

    func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
        switch opcode {
        case .binaryFrame:
            task?.send(.data(data), completionHandler: sendCompletion(completion))
        case .textFrame:
            write(string: String(decoding: data, as: UTF8.self), completion: completion)
        case .ping:
            task?.sendPing(pongReceiveHandler: sendCompletion(completion))
        default:
            break
        }
    }

    func sendCompletion(_ completion: (() -> Void)?) -> (Error?) -> Void {
        { _ in completion?() }
    }

    private func doRead() {
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

    private func broadcast(event: WebSocketEvent) {
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
