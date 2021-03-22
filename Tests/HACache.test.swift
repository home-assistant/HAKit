@testable import HAKit
#if SWIFT_PACKAGE
import HAKit_Mocks
import HAKit_PromiseKit
#endif
import PromiseKit
import XCTest

internal class HACacheTests: XCTestCase {
    private var cache: HACache<CacheItem>!
    private var workQueue: DispatchQueue!

    private var queueSpecific = DispatchSpecificKey<Bool>()
    private var connection: HAMockConnection!

    private var populateInfo: HACachePopulateInfo<CacheItem>!
    private var populateCount: Int!
    private var populateCancellableInvoked: Bool = false
    private var populatePerform: (((CacheItem?) -> CacheItem) -> Void)?

    private var subscribeInfo: HACacheSubscribeInfo<CacheItem>!
    private var subscribeCancellableInvoked: Bool = false
    private var subscribePerform: (((CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) -> Void)?
    private var subscribeInfo2: HACacheSubscribeInfo<CacheItem>!
    private var subscribeCancellableInvoked2: Bool = false
    private var subscribePerform2: (((CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) -> Void)?

    private func waitForCallback() {
        let expectation = self.expectation(description: "waiting for queue")
        workQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    private func populate(_ block: (CacheItem?) -> CacheItem) throws {
        if populatePerform == nil {
            waitForCallback()
        }
        let value = try XCTUnwrap(populatePerform)
        value(block)
    }

    private func subscribe(_ block: (CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) throws {
        if subscribePerform == nil {
            waitForCallback()
        }
        let value = try XCTUnwrap(subscribePerform)
        value(block)
    }

    private func subscribe2(_ block: (CacheItem) -> HACacheSubscribeInfo<CacheItem>.Response) throws {
        if subscribePerform2 == nil {
            waitForCallback()
        }
        let value = try XCTUnwrap(subscribePerform2)
        value(block)
    }

    private var isOnCallbackQueue: Bool {
        DispatchQueue.getSpecific(key: queueSpecific) == true
    }

    override func setUp() {
        super.setUp()

        populateCount = 0
        populateCancellableInvoked = false
        populateInfo = .init(
            request: .init(type: "none", data: [:]),
            anyTransform: { _ in
                fatalError()
            }, start: { [weak self] _, perform in
                self?.populatePerform = perform
                self?.populateCount += 1
                return HAMockCancellable { [weak self] in
                    self?.populateCancellableInvoked = true
                }
            }
        )
        subscribeCancellableInvoked = false
        subscribeCancellableInvoked2 = false
        subscribeInfo = .init(
            request: .init(type: "none", data: [:]),
            anyTransform: { _ in
                fatalError()
            }, start: { [weak self] _, subscribe in
                self?.subscribePerform = subscribe
                return HAMockCancellable { [weak self] in
                    self?.subscribeCancellableInvoked = true
                }
            }
        )
        subscribeInfo2 = .init(
            request: .init(type: "none", data: [:]),
            anyTransform: { _ in
                fatalError()
            }, start: { [weak self] _, subscribe in
                self?.subscribePerform2 = subscribe
                return HAMockCancellable { [weak self] in
                    self?.subscribeCancellableInvoked2 = true
                }
            }
        )

        connection = HAMockConnection()
        queueSpecific = .init()
        connection.callbackQueue = DispatchQueue(label: "test-callback-queue")
        connection.callbackQueue.setSpecific(key: queueSpecific, value: true)
        workQueue = DispatchQueue(label: "work-queue", autoreleaseFrequency: .workItem, target: .global())

        cache = HACache<CacheItem>(connection: connection, populate: populateInfo, subscribe: subscribeInfo)
    }

    func testConstantValue() {
        let expected = CacheItem()
        cache = HACache<CacheItem>(constantValue: expected)
        XCTAssertEqual(cache.value, expected)

        let expectation1 = expectation(description: "subscribe")
        let token = cache.subscribe { _, item in
            XCTAssertFalse(self.isOnCallbackQueue) // the cache doesn't know about the queue
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
        _ = cache.subscribe { _, _ in
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
        _ = cache.subscribe { _, _ in
            XCTFail("should not have invoked subscribe at all")
        }

        _ = cache.subscribe { _, _ in
            XCTFail("should not have invoked subscribe at all")
        }

        XCTAssertEqual(populateCount, 1, "should only populate once")
        XCTAssertNotNil(populatePerform)
        XCTAssertNil(subscribePerform)
    }

    func testResetWithoutSubscribersDisconnects() throws {
        cache.shouldResetWithoutSubscribers = true

        connection.state = .ready(version: "1.2.3")
        let handlerToken = cache.subscribe { _, _ in
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
        let handlerToken = cache.subscribe { _, _ in
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

    func testPopulateThenSubscribes() throws {
        connection.state = .ready(version: "1.2.3")

        let values: [CacheItem] = [.init(), .init(), .init()]

        var handlerValues1 = [CacheItem]()
        var handlerValues2 = [CacheItem]()

        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 6
        let handlerToken1 = cache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            handlerValues1.append(value)
            handlerExpectation.fulfill()
        }
        try populate { current in
            XCTAssertNil(current)
            return values[0]
        }

        populatePerform = nil

        let handlerToken2 = cache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            handlerValues2.append(value)
            handlerExpectation.fulfill()
        }

        try subscribe { current in
            XCTAssertEqual(current, values[0])
            return .ignore
        }

        try subscribe { current in
            XCTAssertEqual(current, values[0])
            return .replace(values[1])
        }

        try subscribe { current in
            XCTAssertEqual(current, values[1])
            return .reissuePopulate
        }

        try populate { current in
            XCTAssertEqual(current, values[1])
            return values[2]
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(populateCount, 2)
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

        _ = cache.subscribe { _, _ in }

        XCTAssertNotNil(populatePerform)
        connection.state = .disconnected(reason: .disconnected)
        populatePerform = nil

        connection.state = .ready(version: "1.2.3")
        XCTAssertEqual(populateCount, 2)
        XCTAssertNotNil(populatePerform)
    }

    func testReissuesPopulateAndSubscribeOnReconnect() throws {
        connection.state = .ready(version: "1.2.3")
        let values: [CacheItem] = [.init(), .init(), .init()]
        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 3
        var handlerValues = [CacheItem]()
        _ = cache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }
        try populate { current in
            XCTAssertNil(current)
            return values[0]
        }
        try subscribe { current in
            XCTAssertEqual(current, values[0])
            return .replace(values[1])
        }
        connection.state = .disconnected(reason: .disconnected)
        connection.state = .ready(version: "2.3.4")
        try populate { current in
            XCTAssertEqual(current, values[1])
            return values[2]
        }
        try subscribe { current in
            XCTAssertEqual(current, values[2])
            return .ignore
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(populateCount, 2)
        XCTAssertEqual(handlerValues, values)
    }

    func testCacheDeallocInvalidatesPopulate() throws {
        connection.state = .ready(version: "1.2.3")
        autoreleasepool {
            _ = cache.subscribe { _, _ in }
            cache = nil
        }

        XCTAssertTrue(populateCancellableInvoked)

        try populate { _ in .init() }
        XCTAssertEqual(populateCount, 1)
    }

    func testCacheDeallocInvalidatesSubscriptions() throws {
        connection.state = .ready(version: "1.2.3")
        try autoreleasepool {
            let expectation = self.expectation(description: "handler")
            _ = cache.subscribe { _, _ in
                XCTAssertTrue(self.isOnCallbackQueue)
                expectation.fulfill()
            }
            try populate { _ in .init() }
            cache = nil
            waitForExpectations(timeout: 10.0)
        }
        XCTAssertTrue(subscribeCancellableInvoked)

        XCTAssertEqual(populateCount, 1)
        try subscribe { _ in .ignore }
    }

    func testMultipleSubscriptions() throws {
        cache = HACache<CacheItem>(
            connection: connection,
            populate: populateInfo,
            subscribe: subscribeInfo,
            subscribeInfo2
        )
        connection.state = .ready(version: "1.2.3")

        var handlerValues: [CacheItem] = []
        let handlerExpectation = expectation(description: "handler")
        handlerExpectation.expectedFulfillmentCount = 3
        _ = cache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }

        let expectedValues: [CacheItem] = [.init(), .init(), .init()]
        try populate { current in
            XCTAssertNil(current)
            return expectedValues[0]
        }

        try subscribe { current in
            XCTAssertEqual(current, expectedValues[0])
            return .replace(expectedValues[1])
        }

        try subscribe2 { current in
            XCTAssertEqual(current, expectedValues[1])
            return .replace(expectedValues[2])
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(handlerValues, expectedValues)
        XCTAssertEqual(populateCount, 1)
    }

    func testMapWithoutExistingValue() throws {
        let mappedCache = cache.map(\.uuid)
        XCTAssertNil(mappedCache.value)

        let handlerExpectation = expectation(description: "handler")
        var handlerValues: [UUID] = []
        handlerExpectation.expectedFulfillmentCount = 2
        let handlerToken = mappedCache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            handlerValues.append(value)
            handlerExpectation.fulfill()
        }

        connection.state = .ready(version: "1.2.3")

        let expectedValues: [CacheItem] = [.init(), .init()]

        try populate { current in
            XCTAssertNil(current)
            return expectedValues[0]
        }

        try subscribe { current in
            XCTAssertEqual(current, expectedValues[0])
            return .replace(expectedValues[1])
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(populateCount, 1)
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

        try populate { current in
            XCTAssertNil(current)
            return expectedValue
        }

        let mappedCache = cache.map(\.uuid)
        XCTAssertEqual(mappedCache.value, expectedValue.uuid)

        let handlerExpectation = expectation(description: "handler")
        _ = mappedCache.subscribe { _, value in
            XCTAssertTrue(self.isOnCallbackQueue)
            XCTAssertEqual(value, expectedValue.uuid)
            handlerExpectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(populateCount, 1)
    }

    func testOnceBeforeInitial() throws {
        connection.state = .ready(version: "1.2.3")
        let expectedValue = CacheItem()

        let regExpectation = expectation(description: "once-regular")
        let pkExpectation = expectation(description: "once-promise")

        cache.once { value in
            XCTAssertEqual(value, expectedValue)
            regExpectation.fulfill()
        }

        cache.once().promise.done { value in
            XCTAssertEqual(value, expectedValue)
            pkExpectation.fulfill()
        }

        try populate { current in
            XCTAssertNil(current)
            return expectedValue
        }

        waitForExpectations(timeout: 10.0)

        try subscribe { current in
            XCTAssertEqual(current, expectedValue)
            return .replace(CacheItem())
        }

        XCTAssertEqual(populateCount, 1)
    }

    func testOnceAfterInitial() throws {
        connection.state = .ready(version: "1.2.3")
        let expectedValue = CacheItem()

        _ = cache.subscribe { _, _ in }

        try populate { current in
            XCTAssertNil(current)
            return expectedValue
        }

        let regExpectation = expectation(description: "once-regular")
        let pkExpectation = expectation(description: "once-promise")

        cache.once { value in
            XCTAssertEqual(value, expectedValue)
            regExpectation.fulfill()
        }

        cache.once().promise.done { value in
            XCTAssertEqual(value, expectedValue)
            pkExpectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        try subscribe { current in
            XCTAssertEqual(current, expectedValue)
            return .replace(CacheItem())
        }

        XCTAssertEqual(populateCount, 1)
    }

    func testOnceCancel() throws {
        connection.state = .ready(version: "1.2.3")
        let expectedValue = CacheItem()

        let regToken = cache.once { _ in
            XCTFail("should not have invoked once")
        }

        let (pkPromise, pkCancel) = cache.once()
        pkPromise.done { _ in
            XCTFail("should not have invoked once")
        }

        regToken.cancel()
        pkCancel()

        try populate { current in
            XCTAssertNil(current)
            return expectedValue
        }

        XCTAssertEqual(populateCount, 1)
    }

    func testStateChangeCancels() throws {
        connection.state = .ready(version: "1.2.3")

        _ = cache.subscribe { _, _ in }

        XCTAssertNotNil(populatePerform)
        connection.state = .ready(version: "1.2.4")
        XCTAssertTrue(populateCancellableInvoked)
        XCTAssertEqual(populateCount, 2)
        XCTAssertNotNil(populatePerform)

        let expectedValue = CacheItem()

        try populate { current in
            XCTAssertNil(current)
            return expectedValue
        }

        populateCancellableInvoked = false
        populatePerform = nil

        connection.state = .ready(version: "1.2.4")

        XCTAssertTrue(subscribeCancellableInvoked)
        XCTAssertFalse(populateCancellableInvoked, "it was already done")
        XCTAssertEqual(populateCount, 3)
        XCTAssertNotNil(populatePerform)
    }
}

private struct CacheItem: Equatable {
    let uuid = UUID()
    static func == (lhs: CacheItem, rhs: CacheItem) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
