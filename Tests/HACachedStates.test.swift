@testable import HAKit
import XCTest
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif

class HACachedStatesTests: XCTestCase {
    private var connection: HAMockConnection!
    private var container: HACachesContainer!

    override func setUp() {
        super.setUp()
        connection = HAMockConnection()
        container = HACachesContainer(connection: connection)
    }

    func testKeyAccess() {
        _ = container.states
    }

    func testPopulateAndSubscribeInfo() throws {
        let cache = container.states
        let populate = try XCTUnwrap(cache.populateInfo)
        let subscribe1 = try XCTUnwrap(cache.subscribeInfo?.get(throwing: 0))

        XCTAssertEqual(populate.request.type, .getStates)
        XCTAssertEqual(subscribe1.request.type, .subscribeEvents)
        XCTAssertEqual(subscribe1.request.data["event_type"] as? String, HAEventType.stateChanged.rawValue)

        let entities = try [HAEntity.fake(id: "1"), HAEntity.fake(id: "2"), HAEntity.fake(id: "3")]

        let result1 = try populate.transform(incoming: entities, current: nil)
        XCTAssertEqual(result1.all, Set(entities))

        for entity in entities {
            XCTAssertEqual(result1[entity.entityId], entity)
        }

        // remove one
        let result2 = try subscribe1.transform(
            incoming: HAResponseEventStateChanged(
                event: HAResponseEvent(
                    type: .stateChanged,
                    timeFired: Date(),
                    data: [:],
                    origin: .local,
                    context: .init(id: "id", userId: nil, parentId: nil)
                ),
                entityId: entities[1].entityId,
                oldState: entities[1],
                newState: nil
            ),
            current: result1
        )

        guard case let .replace(updated1) = result2 else {
            XCTFail("did not replace when expected")
            return
        }

        XCTAssertFalse(updated1.all.contains(entities[1]))
        XCTAssertTrue(updated1.all.contains(entities[0]))
        XCTAssertTrue(updated1.all.contains(entities[2]))
        XCTAssertNil(updated1[entities[1].entityId])
        XCTAssertEqual(updated1[entities[0].entityId], entities[0])
        XCTAssertEqual(updated1[entities[2].entityId], entities[2])

        let addedEntity = try HAEntity.fake(id: "4")
        let result3 = try subscribe1.transform(
            incoming: HAResponseEventStateChanged(
                event: HAResponseEvent(
                    type: .stateChanged,
                    timeFired: Date(),
                    data: [:],
                    origin: .local,
                    context: .init(id: "id", userId: nil, parentId: nil)
                ),
                entityId: addedEntity.entityId,
                oldState: nil,
                newState: addedEntity
            ),
            current: updated1
        )

        guard case let .replace(updated2) = result3 else {
            XCTFail("did not replace when expected")
            return
        }

        XCTAssertTrue(updated2.all.contains(addedEntity))
        XCTAssertTrue(updated2.all.contains(entities[0]))
        XCTAssertTrue(updated2.all.contains(entities[2]))
        XCTAssertEqual(updated2[addedEntity.entityId], addedEntity)
        XCTAssertEqual(updated2[entities[0].entityId], entities[0])
        XCTAssertEqual(updated2[entities[2].entityId], entities[2])

        // update one
        var updatedEntity = try HAEntity.fake(id: "2")
        updatedEntity.state = "updated2"

        let result4 = try subscribe1.transform(
            incoming: HAResponseEventStateChanged(
                event: HAResponseEvent(
                    type: .stateChanged,
                    timeFired: Date(),
                    data: [:],
                    origin: .local,
                    context: .init(id: "id", userId: nil, parentId: nil)
                ),
                entityId: entities[2].entityId,
                oldState: entities[2],
                newState: updatedEntity
            ),
            current: updated2
        )

        guard case let .replace(updated3) = result4 else {
            XCTFail("did not replace when expected")
            return
        }

        XCTAssertTrue(updated3.all.contains(addedEntity))
        XCTAssertTrue(updated3.all.contains(entities[0]))
        XCTAssertTrue(updated3.all.contains(updatedEntity))
        XCTAssertEqual(updated3[addedEntity.entityId], addedEntity)
        XCTAssertEqual(updated3[entities[0].entityId], entities[0])
        XCTAssertEqual(updated3[entities[2].entityId], updatedEntity)

    }
}
