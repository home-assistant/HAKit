@testable import HAWebSocket
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

    private func assertIdle(reconnects: Int = 0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(reconnectManager.reason, .disconnected, file: file, line: line)
        XCTAssertNil(reconnectManager.timer, file: file, line: line)
        XCTAssertEqual(reconnectManager.retryCount, 0, file: file, line: line)
        XCTAssertEqual(delegate.wantsReconnection, reconnects, file: file, line: line)
    }

    func testInitial() {
        assertIdle()
    }

    func testConnecting() {
        reconnectManager.didStartInitialConnect()
        assertIdle()
        reconnectManager.didFinishConnect()
        assertIdle()
    }

    func testConnectThenDisconnectPermanently() {
        reconnectManager.didStartInitialConnect()
        assertIdle()
        reconnectManager.didDisconnectPermanently()
        assertIdle()
    }

    func testConnectThenDisconnectTemporarilyWithError() {
        enum FakeError: Error {
            case error
        }

        let date1 = Date(timeIntervalSinceNow: 10000)
        let date2 = Date(timeIntervalSinceNow: 20000)
        let date3 = Date(timeIntervalSinceNow: 30000)

        HAGlobal.date = { date1 }

        let state1 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: FakeError.error,
            atLatest: date1.addingTimeInterval(5.0),
            retryCount: 1
        )
        let state2 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: FakeError.error,
            atLatest: date2.addingTimeInterval(5.0),
            retryCount: 2
        )
        let state3 = HAConnectionState.DisconnectReason.waitingToReconnect(
            lastError: nil,
            atLatest: date3.addingTimeInterval(5.0),
            retryCount: 3
        )

        reconnectManager.didStartInitialConnect()
        reconnectManager.didDisconnectTemporarily(error: FakeError.error)

        XCTAssertEqual(reconnectManager.reason, state1)

        reconnectManager.timer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 1)
        XCTAssertEqual(reconnectManager.reason, state1)

        HAGlobal.date = { date2 }

        reconnectManager.didDisconnectTemporarily(error: FakeError.error)
        reconnectManager.timer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 2)
        XCTAssertEqual(reconnectManager.reason, state2)

        HAGlobal.date = { date3 }

        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.timer?.fire()
        XCTAssertEqual(delegate.wantsReconnection, 3)
        XCTAssertEqual(reconnectManager.reason, state3)

        reconnectManager.didFinishConnect()
        assertIdle(reconnects: 3)
    }

    func testPathMonitorWithoutTimer() {
        reconnectManager.pathMonitor.pathUpdateHandler?(reconnectManager.pathMonitor.currentPath)
        assertIdle(reconnects: 0)
    }

    func testPathMonitorWithTimer() {
        reconnectManager.didDisconnectTemporarily(error: nil)
        reconnectManager.pathMonitor.pathUpdateHandler?(reconnectManager.pathMonitor.currentPath)
        XCTAssertEqual(delegate.wantsReconnection, 1)
    }
}

private class FakeHAReconnectManagerDelegate: HAReconnectManagerDelegate {
    var wantsReconnection: Int = 0

    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager) {
        wantsReconnection += 1
    }
}
