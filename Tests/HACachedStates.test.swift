@testable import HAKit
import XCTest
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif

internal class HACachedStatesTests: XCTestCase {
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
        XCTAssertNil(cache.populateInfo)
        XCTAssertNil(cache.subscribeInfo)
        let subscribeOnlyInfo = try XCTUnwrap(cache.subscribeOnlyInfo)

        XCTAssertEqual(subscribeOnlyInfo.request.type, .subscribeEntities)
        let result1 = try subscribeOnlyInfo.transform(
            incoming: HACompressedStatesUpdates(
                data: .init(
                    testJsonString: """
                    {
                        "a": {
                            "person.bruno": {
                                "s": "not_home",
                                "a": {
                                    "editable": true,
                                    "id": "bruno",
                                    "latitude": 51.8,
                                    "longitude": 4.5,
                                    "gps_accuracy": 14.1,
                                    "source": "device_tracker.iphone",
                                    "user_id": "12345",
                                    "device_trackers": [
                                        "device_tracker.iphone_15_pro"
                                    ],
                                    "friendly_name": "Bruno"
                                },
                                "c": "01HPKH5TE4HVR88WW6TN43H31X",
                                "lc": 1707884643.671705,
                                "lu": 1707905051.076724
                            }
                        }
                    }
                    """
                )
            ),
            current: nil,
            subscriptionPhase: .initial
        )
        guard case let .replace(outgoingType) = result1 else {
            XCTFail("Did not replace when expected")
            return
        }

        XCTAssertEqual(outgoingType?.all.count, 1)
        XCTAssertEqual(outgoingType?.all.first?.entityId, "person.bruno")
        XCTAssertEqual(outgoingType?.all.first?.state, "not_home")
        XCTAssertEqual(outgoingType?.all.first?.domain, "person")

        let updateEventResult = try subscribeOnlyInfo.transform(
            incoming: HACompressedStatesUpdates(
                data: .init(
                    testJsonString:
                    """
                    {

                            "c": {
                                "person.bruno": {
                                    "+": {
                                        "s": "home",
                                    }
                                }
                            }
                    }
                    """
                )
            ),
            current: .init(HACachedStates(entitiesDictionary: Dictionary(uniqueKeysWithValues: outgoingType!.all.map { (
                $0.entityId,
                $0
            ) }))),
            subscriptionPhase: .iteration
        )

        guard case let .replace(updatedOutgoingType) = updateEventResult else {
            XCTFail("Did not replace updated entity")
            return
        }

        XCTAssertEqual(updatedOutgoingType?.all.count, 1)
        XCTAssertEqual(updatedOutgoingType?.all.first?.entityId, "person.bruno")
        XCTAssertEqual(updatedOutgoingType?.all.first?.state, "home")
        XCTAssertEqual(updatedOutgoingType?.all.first?.domain, "person")

        let entityRemovalEventResult = try subscribeOnlyInfo.transform(
            incoming: HACompressedStatesUpdates(
                data: .init(
                    testJsonString:
                    """
                    {

                            "r": [
                                "person.bruno"
                            ]
                    }
                    """
                )
            ),
            current: .init(entitiesDictionary: Dictionary(
                uniqueKeysWithValues: outgoingType!.all
                    .map { ($0.entityId, $0) }
            )),
            subscriptionPhase: .iteration
        )

        guard case let .replace(entityRemovedOutgoingType) = entityRemovalEventResult else {
            XCTFail("Did not remo entity correctly")
            return
        }

        XCTAssertEqual(entityRemovedOutgoingType?.all.count, 0)
    }
}
