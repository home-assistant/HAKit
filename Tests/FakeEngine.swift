import Foundation
@testable import HAKit

internal class FakeEngine: HAWebSocketEngine {
    weak var delegate: HAWebSocketEngineDelegate?
    var events = [Event]()

    func register(delegate: HAWebSocketEngineDelegate) {
        self.delegate = delegate
    }

    enum Event: Equatable {
        case start(URLRequest)
        case stop(UInt16)
        case forceStop
        case writeString(String)
        case writeData(Data, opcode: HAFrameOpCode)
    }

    func start(request: URLRequest) {
        events.append(.start(request))
    }

    func stop(closeCode: UInt16) {
        events.append(.stop(closeCode))
    }

    func forceStop() {
        events.append(.forceStop)
    }

    func write(data: Data, opcode: HAFrameOpCode, completion: (() -> Void)?) {
        events.append(.writeData(data, opcode: opcode))
        completion?()
    }

    func write(string: String, completion: (() -> Void)?) {
        events.append(.writeString(string))
    }
}
