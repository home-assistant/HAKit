import Foundation

#if canImport(Network)
import Network
#endif

internal enum HAReconnectManagerError: Error {
    case timeout
    case lateFireReset
}

internal protocol HAReconnectManagerDelegate: AnyObject {
    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager)
    func reconnect(
        _ manager: HAReconnectManager,
        wantsDisconnectFor error: Error
    )
    func reconnectManager(
        _ manager: HAReconnectManager,
        pingWithCompletion handler: @escaping (Result<Void, Error>) -> Void
    ) -> HACancellable
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
    struct PingConfig {
        let interval: Measurement<UnitDuration>
        let timeout: Measurement<UnitDuration>
        let lateFireReset: Measurement<UnitDuration>

        func shouldReset(forExpectedFire expectedFire: Date) -> Bool {
            let timeSinceExpectedFire = Measurement<UnitDuration>(
                value: HAGlobal.date().timeIntervalSince(expectedFire),
                unit: .seconds
            )
            return timeSinceExpectedFire > lateFireReset
        }
    }
    static let pingConfig: PingConfig = .init(
        interval: .init(value: 1, unit: .minutes),
        timeout: .init(value: 30, unit: .seconds),
        lateFireReset: .init(value: 5, unit: .minutes)
    )

    weak var delegate: HAReconnectManagerDelegate?

    #if canImport(Network)
    let pathMonitor = NWPathMonitor()
    #endif

    private(set) var retryCount: Int = 0
    private(set) var lastError: Error?
    private(set) var nextTimerDate: Date?
    private(set) var reconnectTimer: Timer? {
        willSet {
            reconnectTimer?.invalidate()
        }

        didSet {
            if let timer = reconnectTimer {
                RunLoop.main.add(timer, forMode: .default)
                nextTimerDate = timer.fireDate
            } else {
                nextTimerDate = nil
            }
        }
    }

    private(set) var lastPingDuration: Measurement<UnitDuration>?
    private(set) var pingTimer: Timer? {
        willSet {
            pingTimer?.invalidate()
        }
        didSet {
            if let timer = pingTimer {
                RunLoop.main.add(timer, forMode: .default)
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
            self?.reconnectTimer?.fire()
        }
        pathMonitor.start(queue: .main)
        #endif
    }

    private func reset() {
        lastPingDuration = nil
        pingTimer = nil
        reconnectTimer = nil
        lastError = nil
        retryCount = 0
    }

    @objc private func retryTimerFired(_ timer: Timer) {
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
        schedulePing()
    }

    func didDisconnectTemporarily(error: Error?) {
        lastError = error

        let delay: TimeInterval = {
            switch retryCount {
            case 0: return 0.0
            case 1: return 5.0
            case 2...3: return 10.0
            default: return 15.0
            }
        }()

        reconnectTimer = Timer(
            fireAt: HAGlobal.date().addingTimeInterval(delay),
            interval: 0,
            target: self,
            selector: #selector(retryTimerFired(_:)),
            userInfo: nil,
            repeats: false
        )
        retryCount += 1
    }

    private func schedulePing() {
        let timer = Timer(
            fire: HAGlobal.date().addingTimeInterval(Self.pingConfig.interval.converted(to: .seconds).value),
            interval: 0,
            repeats: false
        ) { [unowned self] timer in
            guard !Self.pingConfig.shouldReset(forExpectedFire: timer.fireDate) else {
                // Ping timer fired very far after our expected fire date, indicating we were probably suspended
                // The WebSocket connection is going to fail after such a long interval; force a faster reconnect.
                handle(pingResult: .failure(HAReconnectManagerError.lateFireReset))
                return
            }

            sendPing()
        }
        timer.tolerance = 10.0
        pingTimer = timer
    }

    private func sendPing() {
        var timeoutTimer: Timer?
        var pingToken: HACancellable?
        let start = HAGlobal.date()

        pingToken = delegate?.reconnectManager(self, pingWithCompletion: { [weak self] result in
            let end = HAGlobal.date()
            let timeInterval = end.timeIntervalSince(start)
            
            timeoutTimer?.invalidate()
            
            self?.handle(pingResult: result.map {
                return Measurement<UnitDuration>(value: timeInterval, unit: .seconds)
            })
        })

        timeoutTimer = Timer(
            timeInterval: Self.pingConfig.timeout.converted(to: .seconds).value,
            repeats: false
        ) { [weak self] _ in
            pingToken?.cancel()
            self?.handle(pingResult: .failure(HAReconnectManagerError.timeout))
        }
        timeoutTimer?.tolerance = 5.0
        pingTimer = timeoutTimer
    }

    private func handle(pingResult: Result<Measurement<UnitDuration>, Error>) {
        pingTimer = nil

        switch pingResult {
        case let .success(duration):
            lastPingDuration = duration
            schedulePing()
        case let .failure(error):
            delegate?.reconnect(self, wantsDisconnectFor: error)
        }
    }
}
