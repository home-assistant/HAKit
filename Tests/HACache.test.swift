@testable import HAKit
import XCTest

internal class HACacheTests: XCTestCase {
    private var cache: HACache<CacheItem>!

    func testConstantValue() {
        let expected = CacheItem()
        cache = HACache<CacheItem>(constantValue: expected)
        XCTAssertEqual(cache.value, expected)

        let expectation1 = expectation(description: "subscribe")
        let token = cache.subscribe { _, item in
            XCTAssertEqual(item, expected)
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        token.cancel()

        let expectation2 = expectation(description: "once")
        cache.once { value in
            XCTAssertEqual(value, expected)
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(cache.map(\.uuid).value, expected.uuid)
    }
}

private struct CacheItem: Equatable {
    let uuid = UUID()
    static func == (lhs: CacheItem, rhs: CacheItem) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
