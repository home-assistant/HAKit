import Foundation
import Starscream

internal class FakeEngine: Engine {
    weak var delegate: EngineDelegate?
    var events = [Event]()

    func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }

    enum Event: Equatable {
        case start(URLRequest)
        case stop(UInt16)
        case forceStop
        case writeString(String)
        case writeData(Data, opcode: FrameOpCode)
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

    func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
        events.append(.writeData(data, opcode: opcode))
    }

    func write(string: String, completion: (() -> Void)?) {
        events.append(.writeString(string))
    }
}
