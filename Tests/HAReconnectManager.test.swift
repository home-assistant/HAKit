@testable import HAKit
import XCTest

internal class HAReconnectManagerTests: XCTestCase {
    private var reconnectManager: HAReconnectManagerImpl!
    // swiftlint:disable:next weak_delegate
    private var delegate: FakeHAReconnectManagerDelegate!

    override class func setUp() {
        super.setUp()

        // just make sure the default date getter doesn't crash
        _ = HAGlobal.date()
    }

    override func setUp() {
        super.setUp()

        delegate = FakeHAReconnectManagerDelegate()
        reconnectManager = HAReconnectManagerImpl()
        reconnectManager.delegate = delegate
    }

    private func assertIdle(connected: Bool, reconnects: Int = 0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(reconnectManager.reason, .disconnected, file: file, line: line)
        if connected {
            XCTAssertNotNil(reconnectManager.pingTimer, file: file, line: line)
        } else {
            XCTAssertNil(reconnectManager.pingTimer, file: file, line: line)
        }
        XCTAssertNil(reconnectManager.reconnectTimer, file: file, line: line)
        XCTAssertEqual(reconnectManager.retryCount, 0, file: file, line: line)
        XCTAssertEqual(delegate.wantsReconnection, reconnects, file: file, line: line)
    }

    func testInitial() {
        assertIdle(connected: false)
    }

    func testConnecting() {
        reconnectManager.didStartInitialConnect()
        assertIdle(connected: false)
        reconnectManager.didFinishConnect()
        assertIdle(connected: true)
    }

    func testConnectThenDisconnectPermanently() {
        reconnectManager.didStartInitialConnect()
        assertIdle(connected: false)
        reconnectManager.didDisconnectPermanently()
        assertIdle(connected: false)
    }

    func testConnectThenDisconnectRejected() {
        reconnectManager.didStartInitialConnect()
        assertIdle(connected: false)
        reconnectManager.didDisconnectRejected()

        // Should be in rejected state
        XCTAssertEqual(reconnectManager.reason, .rejected)
        XCTAssertNil(reconnectManager.pingTimer)
        XCTAssertNil(reconnectManager.reconnectTimer)
        XCTAssertEqual(reconnectManager.retryCount, 0)
        XCTAssertEqual(delegate.wantsReconnection, 0)
    }

    func testConnectThenDisconnectTemporarilyWithError() {
        enum FakeError: Error {
            case error
        }

        let date1 = Date(timeIntervalSinceNow: 10000)
        let date2 = Date(timeIntervalSinceNow: 20000)
        let date3 = Date(timeIntervalSinceNow: 30000)
        let date4 = Date(timeIntervalSinceNow: 40000)
        let date5 = Date(timeIntervalSinceNow: 50000)

        let state1 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: FakeError.error,
            atLatest: date1.addingTimeInterval(0.0),
            retryCount: 1
        )
        let state2 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: FakeError.error,
            atLatest: date2.addingTimeInterval(5.0),
            retryCount: 2
        )
        let state3 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: nil,
            atLatest: date3.addingTimeInterval(10.0),
            retryCount: 3
        )
        let state4 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: nil,
            atLatest: date4.addingTimeInterval(10.0),
            retryCount: 4
        )
        let state5 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: nil,
            atLatest: date5.addingTimeInterval(15.0),
            retryCount: 5
        )

        HAGlobal.date = { date1 }

        reconnectManager.didStartInitialConnect()
        reconnectManager.didDisconnectTemporarily(error: FakeError.error)

        XCTAssertEqual(reconnectManager.reason, state1)

        reconnectManager.reconnectTimer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 1)
        XCTAssertEqual(reconnectManager.reason, state1)

        HAGlobal.date = { date2 }

        reconnectManager.didDisconnectTemporarily(error: FakeError.error)
        reconnectManager.reconnectTimer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 2)
        XCTAssertEqual(reconnectManager.reason, state2)

        HAGlobal.date = { date3 }

        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.reconnectTimer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 3)
        XCTAssertEqual(reconnectManager.reason, state3)

        HAGlobal.date = { date4 }

        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.reconnectTimer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 4)
        XCTAssertEqual(reconnectManager.reason, state4)

        HAGlobal.date = { date5 }

        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.reconnectTimer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 5)
        XCTAssertEqual(reconnectManager.reason, state5)

        reconnectManager.didFinishConnect()
        assertIdle(connected: true, reconnects: 5)
    }

    func testPathMonitorWithoutTimer() {
        reconnectManager.pathMonitor.pathUpdateHandler?(reconnectManager.pathMonitor.currentPath)
        assertIdle(connected: false, reconnects: 0)
    }

    func testPathMonitorWithTimer() {
        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.pathMonitor.pathUpdateHandler?(reconnectManager.pathMonitor.currentPath)
        XCTAssertEqual(delegate.wantsReconnection, 1)
    }

    func testConnectThenPingSuccess() throws {
        let now = Date(timeIntervalSinceNow: 1000)

        HAGlobal.date = { now }

        reconnectManager.didFinishConnect()
        assertIdle(connected: true)

        let timer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertEqual(timer.fireDate, now.addingTimeInterval(60))
        timer.fire()

        let timeoutTimer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertNotEqual(timeoutTimer, timer)

        let latency: TimeInterval = 5.0

        HAGlobal.date = { now.addingTimeInterval(latency) }

        try XCTUnwrap(delegate.pingHandler)(.success(()))
        XCTAssertFalse(timeoutTimer.isValid)

        XCTAssertEqual(reconnectManager.lastPingDuration?.converted(to: .seconds).value, latency)

        XCTAssertNil(delegate.wantsDisconnectError)

        assertIdle(connected: true)
        XCTAssertNotEqual(reconnectManager.pingTimer, timeoutTimer)
    }

    func testConnectThenPingFailure() throws {
        let now = Date(timeIntervalSinceNow: 1000)

        HAGlobal.date = { now }

        reconnectManager.didFinishConnect()
        assertIdle(connected: true)

        let timer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertEqual(timer.fireDate, now.addingTimeInterval(60))
        timer.fire()

        let timeoutTimer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertNotEqual(timeoutTimer, timer)

        enum SomeError: Error {
            case error
        }

        try XCTUnwrap(delegate.pingHandler)(.failure(SomeError.error))
        XCTAssertFalse(timeoutTimer.isValid)

        XCTAssertNil(reconnectManager.lastPingDuration)
        XCTAssertEqual(delegate.wantsDisconnectError as? SomeError, .error)
    }

    func testConnectThenPingTimeout() throws {
        let now = Date(timeIntervalSinceNow: 1000)

        HAGlobal.date = { now }

        reconnectManager.didFinishConnect()
        assertIdle(connected: true)

        let timer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertEqual(timer.fireDate, now.addingTimeInterval(60))
        timer.fire()

        let timeoutTimer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertNotEqual(timeoutTimer, timer)
        timeoutTimer.fire()

        XCTAssertTrue(delegate.pingCancellableInvoked)

        XCTAssertNil(reconnectManager.lastPingDuration)
        XCTAssertEqual(delegate.wantsDisconnectError as? HAReconnectManagerError, .timeout)
    }

    func testPingTimerFiresSuperLate() throws {
        let now = Date(timeIntervalSinceNow: 1000)

        HAGlobal.date = { now }

        reconnectManager.didFinishConnect()
        assertIdle(connected: true)

        let timer = try XCTUnwrap(reconnectManager.pingTimer)
        XCTAssertEqual(timer.fireDate, now.addingTimeInterval(60))

        HAGlobal.date = { timer.fireDate.addingTimeInterval(500) }

        timer.fire()
        XCTAssertNil(reconnectManager.pingTimer)
        XCTAssertNil(delegate.pingHandler)
        XCTAssertNil(reconnectManager.lastPingDuration)
        XCTAssertEqual(delegate.wantsDisconnectError as? HAReconnectManagerError, .lateFireReset)
    }
}

private class FakeHAReconnectManagerDelegate: HAReconnectManagerDelegate {
    var wantsReconnection: Int = 0

    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager) {
        wantsReconnection += 1
    }

    var pingCancellableInvoked: Bool = false
    var pingHandler: ((Result<Void, Error>) -> Void)?

    func reconnectManager(
        _ manager: HAReconnectManager,
        pingWithCompletion handler: @escaping (Result<Void, Error>) -> Void
    ) -> HACancellable {
        pingHandler = handler
        return HACancellableImpl(handler: { [weak self] in
            self?.pingCancellableInvoked = true
        })
    }

    var wantsDisconnectError: Error?

    func reconnect(_ manager: HAReconnectManager, wantsDisconnectFor error: Error) {
        wantsDisconnectError = error
    }
}
