@testable import HAKit
import HAKit_Mocks
import XCTest

internal class HACacheTests: XCTestCase {
    private var cache: HACache<CacheItem>!
    private var connection: HAMockConnection!

    private var populateInfo: HACachePopulateInfo<CacheItem>!
    private var populateCancellableInvoked: Bool = false
    private var populatePerform: (((CacheItem?) -> CacheItem) -> Void)?

    private var subscribeInfo: HACacheSubscribeInfo<CacheItem>!
    private var subscribeCancellableInvoked: Bool = false
    private var subscribePerform: (((CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) -> Void)?
    private var subscribeInfo2: HACacheSubscribeInfo<CacheItem>!
    private var subscribeCancellableInvoked2: Bool = false
    private var subscribePerform2: (((CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) -> Void)?

    override func setUp() {
        super.setUp()

        populateCancellableInvoked = false
        populateInfo = .init { [weak self] connection, perform in
            self?.populatePerform = perform
            return HAMockCancellable { [weak self] in
                self?.populateCancellableInvoked = true
            }
        }
        subscribeCancellableInvoked = false
        subscribeCancellableInvoked2 = false
        subscribeInfo = .init { [weak self] connection, subscribe in
            self?.subscribePerform = subscribe
            return HAMockCancellable { [weak self] in
                self?.subscribeCancellableInvoked = true
            }
        }
        subscribeInfo2 = .init { [weak self] connection, subscribe in
            self?.subscribePerform2 = subscribe
            return HAMockCancellable { [weak self] in
                self?.subscribeCancellableInvoked2 = true
            }
        }

        connection = HAMockConnection()
        cache = HACache<CacheItem>(connection: connection, populate: populateInfo, subscribe: subscribeInfo)
    }

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

    func testSubscribingSkipsConnectionInitially() throws {
        connection.state = .disconnected(reason: .disconnected)
        _ = cache.subscribe { cancellable, value in
            XCTFail("should not have invoked subscribe at all")
        }

        XCTAssertNil(populatePerform)
        XCTAssertNil(subscribePerform)

        let connection2 = HAMockConnection()
        connection2.state = .ready(version: "2.3.4")
        XCTAssertNil(populatePerform, "unrelated connection shouldn't connect")

        connection.state = .ready(version: "1.2.3")
        XCTAssertNotNil(populatePerform)
    }

    func testSubscribingConnectsImmediately() throws {
        connection.state = .ready(version: "1.2.3")
        _ = cache.subscribe { cancellable, value in
            XCTFail("should not have invoked subscribe at all")
        }

        XCTAssertNotNil(populatePerform)
        XCTAssertNil(subscribePerform)
    }

    func testResetWithoutSubscribersDisconnects() throws {
        cache.shouldResetWithoutSubscribers = true

        connection.state = .ready(version: "1.2.3")
        let handlerToken = cache.subscribe { cancellable, value in
            XCTFail("should not have invoked subscribe at all")
        }

        XCTAssertNotNil(populatePerform)
        XCTAssertNil(subscribePerform)

        handlerToken.cancel()
        XCTAssertTrue(populateCancellableInvoked)
        XCTAssertFalse(subscribeCancellableInvoked)
    }

    func testResetWithoutSubscribersChangedLaterDisconnects() throws {
        connection.state = .ready(version: "1.2.3")
        let handlerToken = cache.subscribe { cancellable, value in
            XCTFail("should not have invoked subscribe at all")
        }

        XCTAssertNotNil(populatePerform)
        XCTAssertNil(subscribePerform)

        handlerToken.cancel()
        XCTAssertFalse(populateCancellableInvoked)

        XCTAssertFalse(cache.shouldResetWithoutSubscribers)
        cache.shouldResetWithoutSubscribers = true
        XCTAssertTrue(cache.shouldResetWithoutSubscribers)
        XCTAssertTrue(populateCancellableInvoked)
    }

    func testPopulateSendsOnRetryToo() throws {
        connection.state = .ready(version: "1.2.3")

        let expectedItem1 = CacheItem()

        let expectation1 = expectation(description: "notified1")
        let handlerToken1 = cache.subscribe { _, value in
            XCTAssertEqual(value, expectedItem1)
            expectation1.fulfill()
        }

        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return expectedItem1
        }

        waitForExpectations(timeout: 10)

        handlerToken1.cancel()
        populatePerform = nil

        let expectedItem2 = CacheItem()

        let expectation2 = expectation(description: "notified2")

        // one initial (since we have a value) and then the after
        expectation2.expectedFulfillmentCount = 2

        var handler2Values = [CacheItem]()
        _ = cache.subscribe { _, value in
            handler2Values.append(value)
            expectation2.fulfill()
        }

        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertEqual(current, expectedItem1)
            return expectedItem2
        }

        waitForExpectations(timeout: 10)

        XCTAssertEqual(handler2Values, [expectedItem1, expectedItem2])
    }

    func testPopulateThenSubscribes() throws {
        connection.state = .ready(version: "1.2.3")

        let values: [CacheItem] = [.init(), .init(), .init()]

        var handlerValues1 = [CacheItem]()
        var handlerValues2 = [CacheItem]()

        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 6
        let handlerToken1 = cache.subscribe { _, value in
            handlerValues1.append(value)
            handlerExpectation.fulfill()
        }
        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return values[0]
        }

        populatePerform = nil

        let handlerToken2 = cache.subscribe { _, value in
            handlerValues2.append(value)
            handlerExpectation.fulfill()
        }

        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, values[0])
            return .ignore
        }

        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, values[0])
            return .replace(values[1])
        }

        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, values[1])
            return .reissuePopulate
        }

        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertEqual(current, values[1])
            return values[2]
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(handlerValues1, values)
        XCTAssertEqual(handlerValues2, values)

        cache.shouldResetWithoutSubscribers = true

        handlerToken1.cancel()
        XCTAssertFalse(subscribeCancellableInvoked)
        handlerToken2.cancel()
        XCTAssertTrue(subscribeCancellableInvoked)
    }

    func testReissuesPopulateOnReconnect() throws {
        connection.state = .ready(version: "1.2.3")

        _ = cache.subscribe { _, _  in }

        XCTAssertNotNil(populatePerform)
        connection.state = .disconnected(reason: .disconnected)
        populatePerform = nil

        connection.state = .ready(version: "1.2.3")
        XCTAssertNotNil(populatePerform)
    }

    func testReissuesPopulateAndSubscribeOnReconnect() throws {
        connection.state = .ready(version: "1.2.3")
        let values: [CacheItem] = [.init(), .init(), .init()]
        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 3
        var handlerValues = [CacheItem]()
        _ = cache.subscribe { _, value in
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }
        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return values[0]
        }
        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, values[0])
            return .replace(values[1])
        }
        connection.state = .disconnected(reason: .disconnected)
        connection.state = .ready(version: "2.3.4")
        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertEqual(current, values[1])
            return values[2]
        }
        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, values[2])
            return .ignore
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(handlerValues, values)
    }

    func testCacheDeallocInvalidatesPopulate() throws {
        connection.state = .ready(version: "1.2.3")
        autoreleasepool {
            _ = cache.subscribe { _, _ in }
            cache = nil
        }

        XCTAssertTrue(populateCancellableInvoked)

        (try XCTUnwrap(populatePerform)) { _ in .init() }
    }

    func testCacheDeallocInvalidatesSubscriptions() throws {
        connection.state = .ready(version: "1.2.3")
        try autoreleasepool {
            let expectation = self.expectation(description: "handler")
            _ = cache.subscribe { _, _ in
                expectation.fulfill()
            }
            (try XCTUnwrap(populatePerform)) { _ in .init() }
            cache = nil
            waitForExpectations(timeout: 10.0)
        }
        XCTAssertTrue(subscribeCancellableInvoked)

        (try XCTUnwrap(subscribePerform)) { _ in .ignore }
    }

    func testMultipleSubscriptions() throws {
        cache = HACache<CacheItem>(connection: connection, populate: populateInfo, subscribe: subscribeInfo, subscribeInfo2)
        connection.state = .ready(version: "1.2.3")

        var handlerValues: [CacheItem] = []
        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 3
        _ = cache.subscribe { _, value in
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }

        let expectedValues: [CacheItem] = [.init(), .init(), .init()]
        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return expectedValues[0]
        }

        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, expectedValues[0])
            return .replace(expectedValues[1])
        }

        (try XCTUnwrap(subscribePerform2)) { current in
            XCTAssertEqual(current, expectedValues[1])
            return .replace(expectedValues[2])
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(handlerValues, expectedValues)
    }

    func testMapWithoutExistingValue() throws {
        let mappedCache = cache.map(\.uuid)
        XCTAssertNil(mappedCache.value)

        let handlerExpectation = expectation(description: "handler")
        var handlerValues: [UUID] = []
        handlerExpectation.expectedFulfillmentCount = 2
        let handlerToken = mappedCache.subscribe { _, value in
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }

        connection.state = .ready(version: "1.2.3")

        let expectedValues: [CacheItem] = [.init(), .init()]

        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return expectedValues[0]
        }

        (try XCTUnwrap(subscribePerform)) { current in
            XCTAssertEqual(current, expectedValues[0])
            return .replace(expectedValues[1])
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(handlerValues, expectedValues.map(\.uuid))

        cache.shouldResetWithoutSubscribers = true
        mappedCache.shouldResetWithoutSubscribers = true

        XCTAssertFalse(subscribeCancellableInvoked)
        handlerToken.cancel()
        XCTAssertTrue(subscribeCancellableInvoked)
    }

    func testMapWithExistingValue() throws {
        connection.state = .ready(version: "1.2.3")
        _ = cache.subscribe { _, _ in }

        let expectedValue = CacheItem()

        (try XCTUnwrap(populatePerform)) { current in
            XCTAssertNil(current)
            return expectedValue
        }

        let mappedCache = cache.map(\.uuid)
        XCTAssertEqual(mappedCache.value, expectedValue.uuid)

        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 2
        _ = mappedCache.subscribe { _, value in
            XCTAssertEqual(value, expectedValue.uuid)
            handlerExpectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }
}

private struct CacheItem: Equatable {
    let uuid = UUID()
    static func == (lhs: CacheItem, rhs: CacheItem) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
