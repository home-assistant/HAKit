import Foundation

#if canImport(Network)
import Network
#endif

internal protocol HAReconnectManagerDelegate: AnyObject {
    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager)
}

internal protocol HAReconnectManager: AnyObject {
    var delegate: HAReconnectManagerDelegate? { get set }
    var reason: HAConnectionState.DisconnectReason { get }

    func didStartInitialConnect()
    func didDisconnectPermanently()
    func didDisconnectTemporarily(error: Error?)
    func didFinishConnect()
}

internal class HAReconnectManagerImpl: HAReconnectManager {
    weak var delegate: HAReconnectManagerDelegate?

    #if canImport(Network)
    let pathMonitor = NWPathMonitor()
    #endif

    private(set) var retryCount: Int = 0
    private(set) var lastError: Error?
    private(set) var nextTimerDate: Date?
    private(set) var timer: Timer? {
        willSet {
            timer?.invalidate()
        }

        didSet {
            if let timer = timer {
                #if swift(>=4.2)
                RunLoop.main.add(timer, forMode: .default)
                #else
                RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
                #endif
                nextTimerDate = timer.fireDate
            } else {
                nextTimerDate = nil
            }
        }
    }

    var reason: HAConnectionState.DisconnectReason {
        guard let nextTimerDate = nextTimerDate else {
            return .disconnected
        }

        return .waitingToReconnect(
            lastError: lastError,
            atLatest: nextTimerDate,
            retryCount: retryCount
        )
    }

    init() {
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            // if we're waiting to reconnect, try now!
            self?.timer?.fire()
        }
        pathMonitor.start(queue: .main)
        #endif
    }

    private func reset() {
        timer = nil
        lastError = nil
        retryCount = 0
    }

    private static func fireDate(for retryCount: Int) -> Date {
        HAGlobal.date().addingTimeInterval(5.0)
    }

    @objc private func timerFired(_ timer: Timer) {
        delegate?.reconnectManagerWantsReconnection(self)
    }

    func didStartInitialConnect() {
        reset()
    }

    func didDisconnectPermanently() {
        reset()
    }

    func didFinishConnect() {
        reset()
    }

    func didDisconnectTemporarily(error: Error?) {
        lastError = error
        timer = Timer(
            fireAt: Self.fireDate(for: retryCount),
            interval: 0,
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: false
        )
        retryCount += 1
    }
}
