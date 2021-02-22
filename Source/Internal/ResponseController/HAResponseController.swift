import Foundation
import Starscream

internal protocol HAResponseControllerDelegate: AnyObject {
    func responseController(
        _ controller: HAResponseController,
        didTransitionTo phase: HAResponseController.Phase
    )
    func responseController(
        _ controller: HAResponseController,
        didReceive response: HAWebSocketResponse
    )
}

internal class HAResponseController {
    weak var delegate: HAResponseControllerDelegate?

    enum Phase {
        case auth
        case command(version: String)
        case disconnected
    }

    var phase: Phase = .disconnected {
        didSet {
            HAGlobal.log("phase transition to \(phase)")
            delegate?.responseController(self, didTransitionTo: phase)
        }
    }

    func didUpdate(to webSocket: WebSocket?) {
        phase = .disconnected
    }
}

extension HAResponseController: Starscream.WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: WebSocket) {
        switch event {
        case let .connected(headers):
            HAGlobal.log("connected with headers: \(headers)")
            phase = .auth
        case let .disconnected(reason, code):
            HAGlobal.log("disconnected: \(reason) with code: \(code)")
            phase = .disconnected
        case let .text(string):
            HAGlobal.log("Received text: \(string)")
            do {
                if let data = string.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let response = try HAWebSocketResponse(dictionary: json)

                    if case let .auth(.ok(version)) = response {
                        phase = .command(version: version)
                    }

                    delegate?.responseController(self, didReceive: response)
                }
            } catch {
                HAGlobal.log("text parse error: \(error)")
            }
        case let .binary(data):
            HAGlobal.log("Received binary data: \(data.count)")
        case .ping, .pong:
            break
        case .reconnectSuggested:
            break
        case .viabilityChanged:
            break
        case .cancelled:
            phase = .disconnected
        case let .error(error):
            HAGlobal.log("connection error: \(String(describing: error))")
            phase = .disconnected
        }
    }
}
