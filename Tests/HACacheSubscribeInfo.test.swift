@testable import HAKit
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif
import XCTest

internal class HACacheSubscribeInfoTests: XCTestCase {
    private var connection: HAMockConnection!
    private var subscription: HATypedSubscription<SubscribeItem>!

    override func setUp() {
        super.setUp()
        subscription = HATypedSubscription<SubscribeItem>(request: .init(type: "test", data: ["in_data": true]))
        connection = HAMockConnection()
    }

    func testTryTransform() throws {
        var result: HACacheSubscribeInfo<SubscribeItem>.Response = .ignore
        let item = SubscribeItem()

        let info = HACacheSubscribeInfo<SubscribeItem>(
            subscription: subscription, transform: { value in
                XCTAssertEqual(value.current, item)
                return result
            }
        )
        XCTAssertEqual(info.request.type, "test")
        XCTAssertEqual(info.request.data["in_data"] as? Bool, true)

        XCTAssertThrowsError(try info.transform(incoming: "hello", current: item))
        XCTAssertThrowsError(try info.transform(incoming: SubscribeItem?.none, current: item))

        result = .reissuePopulate
        XCTAssertEqual(try info.transform(incoming: item, current: item), result)

        result = .replace(SubscribeItem())
        XCTAssertEqual(try info.transform(incoming: item, current: item), result)
    }

    func testNotRetryRequest() throws {
        let info = HACacheSubscribeInfo<SubscribeWrapper>(subscription: subscription, transform: { _ in .ignore })

        _ = info.start(connection) { _ in }

        let sent = try XCTUnwrap(connection.pendingSubscriptions.first)
        XCTAssertTrue(subscription.request.shouldRetry)
        XCTAssertFalse(sent.request.shouldRetry)
        XCTAssertEqual(sent.request.type, "test")
        XCTAssertEqual(sent.request.data["in_data"] as? Bool, true)
    }

    func testSubscribeHandlerInvoked() throws {
        let existing = SubscribeItem()
        let updated = SubscribeItem()

        let result: HACacheSubscribeInfo<SubscribeWrapper>.Response = .ignore

        let subscribeInfo = HACacheSubscribeInfo<SubscribeWrapper>(subscription: subscription, transform: { info in
            XCTAssertEqual(info.incoming, updated)
            XCTAssertEqual(info.current?.subscribeItem, existing)
            return result
        })

        let invoked = expectation(description: "invoked")

        let token = subscribeInfo.start(connection) { handler in
            XCTAssertEqual(handler(.init(subscribeItem: existing)), result)
            invoked.fulfill()
        }

        let request = try XCTUnwrap(connection.pendingSubscriptions.get(throwing: 0))
        request.handler(HACancellableImpl(handler: {}), updated.data)

        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(connection.cancelledRequests.isEmpty)

        token.cancel()

        XCTAssertTrue(connection.cancelledSubscriptions.contains(where: {
            $0.type == subscription.request.type
        }))
    }
}

private class SubscribeWrapper: Equatable {
    static func == (lhs: SubscribeWrapper, rhs: SubscribeWrapper) -> Bool {
        lhs.subscribeItem == rhs.subscribeItem
    }

    let subscribeItem: SubscribeItem
    init(subscribeItem: SubscribeItem) {
        self.subscribeItem = subscribeItem
    }
}

private class SubscribeItem: HADataDecodable, Equatable {
    let uuid: UUID

    init() {
        self.uuid = UUID()
    }

    required init(data: HAData) throws {
        self.uuid = try data.decode("uuid", transform: UUID.init(uuidString:))
    }

    var data: HAData {
        .dictionary(["uuid": uuid.uuidString])
    }

    static func == (lhs: SubscribeItem, rhs: SubscribeItem) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
