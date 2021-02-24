@testable import HAWebSocket
import XCTest

internal class CurrentUserTests: XCTestCase {
    func testRequest() {
        let request = HATypedRequest<HAResponseCurrentUser>.currentUser()
        XCTAssertEqual(request.request.type, .currentUser)
        XCTAssertEqual(request.request.data.count, 0)
        XCTAssertEqual(request.request.shouldRetry, true)
    }

    func testResponseWithFullValues() throws {
        let data = HAData(testJsonString: """
        {
            "id": "76ce52a813c44fdf80ee36f926d62328",
            "name": "Dev User",
            "is_owner": false,
            "is_admin": true,
            "credentials": [
                {
                    "auth_provider_type": "homeassistant",
                    "auth_provider_id": null
                },
                {
                    "auth_provider_type": "test",
                    "auth_provider_id": "abc"
                }
            ],
            "mfa_modules": [
                {
                    "id": "totp",
                    "name": "Authenticator app",
                    "enabled": false
                },
                {
                    "id": "sms",
                    "name": "SMS",
                    "enabled": true
                },
            ]
        }
        """)
        let user = try HAResponseCurrentUser(data: data)
        XCTAssertEqual(user.id, "76ce52a813c44fdf80ee36f926d62328")
        XCTAssertEqual(user.name, "Dev User")
        XCTAssertEqual(user.isOwner, false)
        XCTAssertEqual(user.isAdmin, true)
        XCTAssertEqual(user.credentials.count, 2)

        let credential1 = try user.credentials.get(throwing: 0)
        let credential2 = try user.credentials.get(throwing: 1)
        XCTAssertEqual(credential1.id, nil)
        XCTAssertEqual(credential1.type, "homeassistant")
        XCTAssertEqual(credential2.id, "abc")
        XCTAssertEqual(credential2.type, "test")

        let mfaModule1 = try user.mfaModules.get(throwing: 0)
        let mfaModule2 = try user.mfaModules.get(throwing: 1)
        XCTAssertEqual(mfaModule1.id, "totp")
        XCTAssertEqual(mfaModule1.name, "Authenticator app")
        XCTAssertEqual(mfaModule1.isEnabled, false)
        XCTAssertEqual(mfaModule2.id, "sms")
        XCTAssertEqual(mfaModule2.name, "SMS")
        XCTAssertEqual(mfaModule2.isEnabled, true)
    }

    func testResponseWithMinimalValues() throws {
        let data = HAData(testJsonString: """
        {
            "id": "76ce52a813c44fdf80ee36f926d62328"
        }
        """)
        let user = try HAResponseCurrentUser(data: data)
        XCTAssertEqual(user.id, "76ce52a813c44fdf80ee36f926d62328")
        XCTAssertEqual(user.name, nil)
        XCTAssertEqual(user.isOwner, false)
        XCTAssertEqual(user.isAdmin, false)
        XCTAssertEqual(user.credentials.count, 0)
        XCTAssertEqual(user.mfaModules.count, 0)
    }
}
