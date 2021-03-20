@testable import HAKit
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif
import XCTest

internal class HACachePopulateInfoTests: XCTestCase {
    private var connection: HAMockConnection!
    private var request: HATypedRequest<PopulateItem>!

    override func setUp() {
        super.setUp()
        request = HATypedRequest<PopulateItem>(request: .init(type: "test", data: ["in_data": true]))
        connection = HAMockConnection()
    }

    func testTryTransform() throws {
        let info = HACachePopulateInfo(request: request, transform: \.incoming)
        XCTAssertEqual(info.request.type, "test")
        XCTAssertEqual(info.request.data["in_data"] as? Bool, true)

        XCTAssertThrowsError(try info.transform(incoming: "hello", current: nil))
        XCTAssertThrowsError(try info.transform(incoming: PopulateItem?.none, current: nil))

        let item = PopulateItem()
        XCTAssertEqual(try info.transform(incoming: item, current: item), item)
        XCTAssertEqual(try info.transform(incoming: item, current: nil), item)
    }

    func testNotRetryRequest() throws {
        let info = HACachePopulateInfo(request: request, transform: \.incoming)

        _ = info.start(connection) { _ in }

        let sent = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertTrue(request.request.shouldRetry)
        XCTAssertFalse(sent.request.shouldRetry)
        XCTAssertEqual(sent.request.type, "test")
        XCTAssertEqual(sent.request.data["in_data"] as? Bool, true)
    }

    func testSendSucceeds() throws {
        let existing = PopulateItem()
        let updated = PopulateItem()

        let populateInfo: HACachePopulateInfo<PopulateWrapper> = HACachePopulateInfo(
            request: request,
            transform: { info in
                XCTAssertEqual(info.incoming, updated)
                XCTAssertEqual(info.current?.populateItem, existing)
                return PopulateWrapper(populateItem: info.incoming)
            }
        )

        let invoked = expectation(description: "invoked")

        _ = populateInfo.start(connection) { handler in
            XCTAssertEqual(handler(.init(populateItem: existing)).populateItem, updated)
            invoked.fulfill()
        }

        let request = try XCTUnwrap(connection.pendingRequests.get(throwing: 0))
        request.completion(.success(updated.data))

        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(connection.cancelledRequests.isEmpty)
    }

    func testSendFails() throws {
        let populateInfo = HACachePopulateInfo<PopulateWrapper>(request: request, transform: { info in
            XCTFail("should not have invoked request transform")
            return PopulateWrapper(populateItem: info.incoming)
        })

        _ = populateInfo.start(connection) { _ in
            XCTFail("should not have invoked")
        }

        let request = try XCTUnwrap(connection.pendingRequests.get(throwing: 0))
        request.completion(.failure(.internal(debugDescription: "unit-test")))

        XCTAssertTrue(connection.cancelledRequests.isEmpty)
    }

    func testSendCancelled() {
        let populateInfo = HACachePopulateInfo<PopulateWrapper>(request: request, transform: { info in
            XCTFail("should not have invoked request transform")
            return PopulateWrapper(populateItem: info.incoming)
        })

        let token = populateInfo.start(connection) { _ in
            XCTFail("should not have invoked")
        }

        token.cancel()
        XCTAssertTrue(connection.cancelledRequests.contains(where: { possible in
            possible.type == request.request.type
        }))
    }
}

private class PopulateWrapper {
    let populateItem: PopulateItem
    init(populateItem: PopulateItem) {
        self.populateItem = populateItem
    }
}

private class PopulateItem: HADataDecodable, Equatable {
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

    static func == (lhs: PopulateItem, rhs: PopulateItem) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
