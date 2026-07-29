import Foundation

/// Receives events from an ``HAWebSocket``.
internal protocol HAWebSocketDelegate: AnyObject {
    func didReceive(event: HAWebSocketEvent)
}

/// A WebSocket client.
///
/// This is a thin wrapper around an ``HAWebSocketEngine`` (by default
/// ``HAURLSessionWebSocketEngine``, backed by `URLSessionWebSocketTask`). It owns the engine,
/// registers itself as the engine's delegate, and forwards transport events to its own delegate.
internal final class HAWebSocket {
    /// The request used to open the connection.
    let request: URLRequest

    /// The object notified of connection events.
    weak var delegate: HAWebSocketDelegate?

    private let engine: HAWebSocketEngine
    private var isStopped = false

    init(request: URLRequest, engine: HAWebSocketEngine) {
        self.request = request
        self.engine = engine
        engine.register(delegate: self)
    }

    deinit {
        // The engine's URLSession retains the engine (its delegate) until invalidated, so the engine
        // would otherwise outlive this socket. Only a fallback for connections dropped without an
        // explicit `disconnect()`; a disconnected socket has already torn the engine down.
        if !isStopped {
            engine.forceStop()
        }
    }

    /// Open the connection.
    func connect() {
        engine.start(request: request)
    }

    /// Close the connection with the given RFC 6455 close code.
    func disconnect(closeCode: UInt16 = HACloseCode.normalClosure.rawValue) {
        isStopped = true
        engine.stop(closeCode: closeCode)
    }

    /// Send a text frame.
    func write(string: String, completion: (() -> Void)? = nil) {
        engine.write(string: string, completion: completion)
    }

    /// Send a binary frame.
    func write(data: Data, completion: (() -> Void)? = nil) {
        engine.write(data: data, opcode: .binaryFrame, completion: completion)
    }
}

extension HAWebSocket: HAWebSocketEngineDelegate {
    func didReceive(event: HAWebSocketEvent) {
        // The engine delivers events on its `URLSession` background delegate queue. `HAConnection` and
        // the response controller mutate main-confined state (connection, phase) and assert
        // `Thread.isMainThread` on disconnect, so — like the previous transport — hop to the main queue
        // before forwarding.
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceive(event: event)
        }
    }
}
