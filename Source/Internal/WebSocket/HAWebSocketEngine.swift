import Foundation

/// The low-level transport that performs the actual WebSocket I/O.
///
/// HAKit ships a single implementation, ``HAURLSessionWebSocketEngine``, backed by
/// `URLSessionWebSocketTask`. The protocol exists so tests can inject a fake transport.
internal protocol HAWebSocketEngine: AnyObject {
    /// Register the object that should receive transport events.
    func register(delegate: HAWebSocketEngineDelegate)
    /// Open the connection for the given request.
    func start(request: URLRequest)
    /// Close the connection with the given RFC 6455 close code.
    func stop(closeCode: UInt16)
    /// Close the connection abnormally, without a clean handshake.
    func forceStop()
    /// Send a text frame.
    func write(string: String, completion: (() -> Void)?)
    /// Send a frame of the given kind.
    func write(data: Data, opcode: HAFrameOpCode, completion: (() -> Void)?)
}

/// Receives events emitted by an ``HAWebSocketEngine``.
internal protocol HAWebSocketEngineDelegate: AnyObject {
    func didReceive(event: HAWebSocketEvent)
}

/// The kind of frame to write over the connection.
internal enum HAFrameOpCode: Equatable {
    case textFrame
    case binaryFrame
    case ping
    case pong
}

/// RFC 6455 close codes used by the library.
internal enum HACloseCode: UInt16 {
    case normalClosure = 1000
    case goingAway = 1001
}

/// An event produced by the WebSocket transport.
///
/// This mirrors the subset of events HAKit relied on from its previous WebSocket dependency. The
/// current transport (``HAURLSessionWebSocketEngine``) only emits `connected`, `disconnected`,
/// `text`, `binary` and `error`; the remaining cases are retained so the response controller keeps
/// handling them defensively.
internal enum HAWebSocketEvent {
    case connected([String: String])
    case disconnected(String, UInt16)
    case text(String)
    case binary(Data)
    case ping(Data?)
    case pong(Data?)
    case viabilityChanged(Bool)
    case reconnectSuggested(Bool)
    case cancelled
    case peerClosed
    case error(Error?)
}

extension HAWebSocketEvent: Equatable {
    static func == (lhs: HAWebSocketEvent, rhs: HAWebSocketEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.connected(lhsValue), .connected(rhsValue)):
            return lhsValue == rhsValue
        case let (.disconnected(lhsReason, lhsCode), .disconnected(rhsReason, rhsCode)):
            return lhsReason == rhsReason && lhsCode == rhsCode
        case let (.text(lhsValue), .text(rhsValue)):
            return lhsValue == rhsValue
        case let (.binary(lhsValue), .binary(rhsValue)):
            return lhsValue == rhsValue
        case let (.ping(lhsValue), .ping(rhsValue)):
            return lhsValue == rhsValue
        case let (.pong(lhsValue), .pong(rhsValue)):
            return lhsValue == rhsValue
        case let (.viabilityChanged(lhsValue), .viabilityChanged(rhsValue)):
            return lhsValue == rhsValue
        case let (.reconnectSuggested(lhsValue), .reconnectSuggested(rhsValue)):
            return lhsValue == rhsValue
        case (.cancelled, .cancelled):
            return true
        case (.peerClosed, .peerClosed):
            return true
        case let (.error(lhsValue), .error(rhsValue)):
            return lhsValue as NSError? == rhsValue as NSError?
        default:
            return false
        }
    }
}
