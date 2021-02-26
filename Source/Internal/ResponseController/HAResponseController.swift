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

    enum Phase: Equatable {
        case auth
        case command(version: String)
        case disconnected
    }

    private(set) var phase: Phase = .disconnected {
        didSet {
            HAGlobal.log("phase transition to \(phase)")
            delegate?.responseController(self, didTransitionTo: phase)
        }
    }

    func reset() {
        phase = .disconnected
    }

    func didReceive(event: Starscream.WebSocketEvent) {
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
            // automatically handled by Starscream
            break
        case .reconnectSuggested, .viabilityChanged:
            // doesn't look like the URLSession variant calls this
            break
        case .cancelled:
            phase = .disconnected
        case let .error(error):
            HAGlobal.log("connection error: \(String(describing: error))")
            phase = .disconnected
        }
    }
}
