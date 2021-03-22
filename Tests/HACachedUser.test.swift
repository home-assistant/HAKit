import HAKit
import XCTest
#if SWIFT_PACKAGE
import HAKit_Mocks
#endif

internal class HACachedUserTests: XCTestCase {
    private var connection: HAMockConnection!
    private var container: HACachesContainer!

    override func setUp() {
        super.setUp()
        connection = HAMockConnection()
        container = HACachesContainer(connection: connection)
    }

    func testKeyAccess() {
        _ = container.user
    }

    func testRequest() throws {
        let cache = container.user
        let populate = try XCTUnwrap(cache.populateInfo)
        XCTAssertTrue(cache.subscribeInfo?.isEmpty ?? false)

        XCTAssertEqual(populate.request.type, .currentUser)
        XCTAssertTrue(populate.request.data.isEmpty)

        let user = HAResponseCurrentUser(
            id: "id",
            name: "name",
            isOwner: false,
            isAdmin: false,
            credentials: [],
            mfaModules: []
        )
        let result = try populate.transform(incoming: user, current: nil)
        XCTAssertEqual(result.id, user.id)
        XCTAssertEqual(result.name, user.name)
    }
}
