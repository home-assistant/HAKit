@testable import HAWebSocket
import XCTest

internal class HAResetLockTests: XCTestCase {
    func testReset() {
        iteration {
            let (lock, callCount) = build { idx, lock in
                if idx.isMultiple(of: 2) {
                    lock.read()?()
                } else {
                    lock.reset()
                }
            }

            // this is mostly just testing that it doesn't crash, and doesn't give very large numbers
            XCTAssertLessThan(callCount, 5)
            XCTAssertNil(lock.read())
            XCTAssertNil(lock.pop())
        }
    }

    func testRead() {
        iteration {
            let (lock, callCount) = build { _, lock in
                lock.read()?()
            }

            XCTAssertEqual(callCount, 100)
            XCTAssertNotNil(lock.read())
            XCTAssertNotNil(lock.pop())
        }
    }

    func testPop() {
        iteration {
            let (lock, callCount) = build { _, lock in
                lock.pop()?()
            }

            XCTAssertEqual(callCount, 1)
            XCTAssertNil(lock.pop())
            XCTAssertNil(lock.read())
        }
    }

    private typealias LockValue = () -> Void

    private func iteration(_ block: () -> Void) {
        for _ in stride(from: 0, to: 100, by: 1) {
            block()
        }
    }

    private func build(
        with block: (Int, HAResetLock<LockValue>) -> Void
    ) -> (lock: HAResetLock<LockValue>, callCount: Int32) {
        var callCount: Int32 = 0

        let lock = HAResetLock<() -> Void>(value: {
            OSAtomicIncrement32(&callCount)
        })

        DispatchQueue.concurrentPerform(iterations: 100, execute: {
            block($0, lock)
        })

        return (lock, callCount)
    }
}
