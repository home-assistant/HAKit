@testable import HAKit
import XCTest
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif

internal class HACachesContainerTests: XCTestCase {
    private var connection: HAMockConnection!
    private var container: HACachesContainer!

    override func setUp() {
        super.setUp()
        connection = HAMockConnection()
        container = HACachesContainer(connection: connection)
    }

    func testCreate() throws {
        let cache1 = container[Key1.self]
        XCTAssertEqual(try ObjectIdentifier(XCTUnwrap(cache1.connection)), ObjectIdentifier(connection))

        XCTAssertEqual(cache1.populateInfo?.request.type, "key1_pop")
        XCTAssertEqual(cache1.subscribeInfo?.count, 1)
        XCTAssertEqual(cache1.subscribeInfo?.first?.request.type, "key1_sub")
    }

    func testSingleCacheCreated() {
        let cache1a = container[Key1.self]
        let cache2a = container[Key2.self]
        let cache1b = container[Key1.self]
        let cache2b = container[Key2.self]

        XCTAssertEqual(ObjectIdentifier(cache1a), ObjectIdentifier(cache1b))
        XCTAssertEqual(ObjectIdentifier(cache2a), ObjectIdentifier(cache2b))
    }

    func testSameTypeNotDuplicate() {
        let cache1 = container[Key1.self]
        let cache2 = container[Key2.self]
        XCTAssertNotEqual(ObjectIdentifier(cache1), ObjectIdentifier(cache2))
    }
}

private struct Key1: HACacheKey {
    static func create(connection: HAConnection) -> HACache<Value1> {
        .init(
            connection: connection,
            populate: HACachePopulateInfo<Value1>(
                request: HATypedRequest<Value1>(request: .init(type: "key1_pop", data: [:])),
                transform: \.incoming
            ),
            subscribe: HACacheSubscribeInfo<Value1>(
                subscription: HATypedSubscription<Value1>(request: .init(type: "key1_sub", data: [:])),
                transform: { .replace($0.incoming) }
            )
        )
    }
}

private struct Value1: HADataDecodable {
    init(data: HAData) throws {}
}

private struct Key2: HACacheKey {
    static func create(connection: HAConnection) -> HACache<Value1> {
        .init(
            connection: connection,
            populate: HACachePopulateInfo<Value1>(
                request: HATypedRequest<Value1>(request: .init(type: "key1_pop", data: [:])),
                transform: \.incoming
            ),
            subscribe: HACacheSubscribeInfo<Value1>(
                subscription: HATypedSubscription<Value1>(request: .init(type: "key1_sub", data: [:])),
                transform: { .replace($0.incoming) }
            )
        )
    }
}
