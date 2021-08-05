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

    private struct State {
        var retryCount: Int = 0
        var lastError: Error?
        var nextTimerDate: Date?
        @HASchedulingTimer var reconnectTimer: Timer? {
            didSet {
                nextTimerDate = reconnectTimer?.fireDate
            }
        }

        var lastPingDuration: Measurement<UnitDuration>?
        @HASchedulingTimer var pingTimer: Timer?

        mutating func reset() {
            lastPingDuration = nil
            pingTimer = nil
            reconnectTimer = nil
            lastError = nil
            retryCount = 0
        }
    }

    private let state = HAProtected<State>(value: .init())

    var reason: HAConnectionState.DisconnectReason {
        state.read { state in
            guard let nextTimerDate = state.nextTimerDate else {
                return .disconnected
            }

            return .waitingToReconnect(
                lastError: state.lastError,
                atLatest: nextTimerDate,
                retryCount: state.retryCount
            )
        }
    }

    init() {
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            // if we're waiting to reconnect, try now!
            self?.state.read(\.reconnectTimer)?.fire()
        }
        pathMonitor.start(queue: .main)
        #endif
    }

    private func reset() {
        state.mutate { state in
            state.reset()
        }
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
        state.mutate { state in
            state.lastError = error

            let delay: TimeInterval = {
                switch state.retryCount {
                case 0: return 0.0
                case 1: return 5.0
                case 2, 3: return 10.0
                default: return 15.0
                }
            }()

            state.reconnectTimer = Timer(
                fireAt: HAGlobal.date().addingTimeInterval(delay),
                interval: 0,
                target: self,
                selector: #selector(retryTimerFired(_:)),
                userInfo: nil,
                repeats: false
            )
            state.retryCount += 1
        }
    }

    private func schedulePing() {
        let timer = Timer(
            fire: HAGlobal.date().addingTimeInterval(Self.pingConfig.interval.converted(to: .seconds).value),
            interval: 0,
            repeats: false
        ) { [weak self] timer in
            guard !Self.pingConfig.shouldReset(forExpectedFire: timer.fireDate) else {
                // Ping timer fired very far after our expected fire date, indicating we were probably suspended
                // The WebSocket connection is going to fail after such a long interval; force a faster reconnect.
                self?.handle(pingResult: .failure(HAReconnectManagerError.lateFireReset))
                return
            }

            self?.sendPing()
        }
        timer.tolerance = 10.0

        state.mutate { state in
            state.pingTimer = timer
        }
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
                Measurement<UnitDuration>(value: timeInterval, unit: .seconds)
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

        state.mutate { state in
            state.pingTimer = timeoutTimer
        }
    }

    private func handle(pingResult: Result<Measurement<UnitDuration>, Error>) {
        let needsReschedule = state.mutate { state -> Bool in
            state.pingTimer = nil

            switch pingResult {
            case let .success(duration):
                state.lastPingDuration = duration
                return true
            case let .failure(error):
                delegate?.reconnect(self, wantsDisconnectFor: error)
                return false
            }
        }

        if needsReschedule {
            schedulePing()
        }
    }
}

// for tests
extension HAReconnectManagerImpl {
    var reconnectTimer: Timer? {
        state.read(\.reconnectTimer)
    }

    var lastPingDuration: Measurement<UnitDuration>? {
        state.read(\.lastPingDuration)
    }

    var pingTimer: Timer? {
        state.read(\.pingTimer)
    }

    var retryCount: Int {
        state.read(\.retryCount)
    }
}
