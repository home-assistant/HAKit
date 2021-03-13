@testable import HAKit
import XCTest

internal class CallServiceTests: XCTestCase {
    func testCallServiceRequestWithoutData() {
        let request = HATypedRequest<HAResponseVoid>.callService(
            domain: "some_domain",
            service: "some_service"
        )
        XCTAssertEqual(request.request.type, .callService)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["domain"] as? String, "some_domain")
        XCTAssertEqual(request.request.data["service"] as? String, "some_service")
        XCTAssertEqual((request.request.data["service_data"] as? [String: Any])?.count, 0)
    }

    func testCallServiceRequestWithData() {
        let request = HATypedRequest<HAResponseVoid>.callService(
            domain: "some_domain",
            service: "some_service",
            data: [
                "key1": 1,
                "key2": true,
                "key3": ["yes", "or", "no"],
            ]
        )
        XCTAssertEqual(request.request.type, .callService)
        XCTAssertEqual(request.request.shouldRetry, true)
        XCTAssertEqual(request.request.data["domain"] as? String, "some_domain")
        XCTAssertEqual(request.request.data["service"] as? String, "some_service")

        guard let data = request.request.data["service_data"] as? [String: Any] else {
            XCTFail("service data was not provided when we expected it to be")
            return
        }

        XCTAssertEqual(data["key1"] as? Int, 1)
        XCTAssertEqual(data["key2"] as? Bool, true)
        XCTAssertEqual(data["key3"] as? [String], ["yes", "or", "no"])
    }

    func testCallServiceResponse() {
        // response is type void, no need to test
    }

    func testGetServicesRequest() {
        let request = HATypedRequest<HAResponseServices>.getServices()
        XCTAssertEqual(request.request.type, .getServices)
    }

    func testGetServicesResponse() throws {
        let data = HAData(testJsonString: """
        {
            "persistent_notification": {
                "create": {
                    "name": "",
                    "description": "Show a notification in the frontend.",
                    "fields": {
                        "message": {
                            "description": "Message body of the notification. [Templates accepted]",
                            "example": "Please check your configuration.yaml."
                        },
                        "title": {
                            "description": "Optional title for your notification. [Optional, Templates accepted]",
                            "example": "Test notification"
                        },
                        "notification_id": {
                            "description": "Target ID of the notification, will replace a notification with the same ID. [Optional]",
                            "example": 1234
                        }
                    }
                },
                "dismiss": {
                    "name": "",
                    "description": "Remove a notification from the frontend.",
                    "fields": {
                        "notification_id": {
                            "description": "Target ID of the notification, which should be removed. [Required]",
                            "example": 1234
                        }
                    }
                },
                "mark_read": {
                    "name": "",
                    "description": "Mark a notification read.",
                    "fields": {
                        "notification_id": {
                            "description": "Target ID of the notification, which should be mark read. [Required]",
                            "example": 1234
                        }
                    }
                }
            },
            "homeassistant": {
                "turn_off": {
                    "name": "Generic turn off",
                    "description": "Generic service to turn devices off under any domain.",
                    "fields": {}
                },
                "turn_on": {
                    "name": "Generic turn on",
                    "description": "Generic service to turn devices on under any domain.",
                    "fields": {}
                }
            }
        }
        """)
        let response = try HAResponseServices(data: data)
        XCTAssertEqual(response.all.count, 5)
        XCTAssertEqual(response.all.map(\.domainServicePair), [
            "homeassistant.turn_off",
            "homeassistant.turn_on",
            "persistent_notification.create",
            "persistent_notification.dismiss",
            "persistent_notification.mark_read",
        ])

        let ha = try XCTUnwrap(response.allByDomain["homeassistant"])
        XCTAssertEqual(ha.count, 2)

        var service: HAServiceDefinition!

        service = try XCTUnwrap(ha["turn_on"])
        XCTAssertEqual(service.domain, "homeassistant")
        XCTAssertEqual(service.service, "turn_on")
        XCTAssertEqual(service.domainServicePair, "homeassistant.turn_on")
        XCTAssertEqual(service.name, "Generic turn on")
        XCTAssertEqual(service.description, "Generic service to turn devices on under any domain.")
        XCTAssertTrue(service.fields.isEmpty)

        service = try XCTUnwrap(ha["turn_off"])
        XCTAssertEqual(service.domain, "homeassistant")
        XCTAssertEqual(service.service, "turn_off")
        XCTAssertEqual(service.domainServicePair, "homeassistant.turn_off")
        XCTAssertEqual(service.name, "Generic turn off")
        XCTAssertEqual(service.description, "Generic service to turn devices off under any domain.")
        XCTAssertTrue(service.fields.isEmpty)

        let pers = try XCTUnwrap(response.allByDomain["persistent_notification"])
        XCTAssertEqual(pers.count, 3)

        service = try XCTUnwrap(pers["create"])
        XCTAssertEqual(service.domain, "persistent_notification")
        XCTAssertEqual(service.service, "create")
        XCTAssertEqual(service.domainServicePair, "persistent_notification.create")
        XCTAssertEqual(service.name, "persistent_notification.create", "we modified this")
        XCTAssertEqual(service.description, "Show a notification in the frontend.")
        XCTAssertEqual(service.fields["message"] as? [String: String], [
            "description": "Message body of the notification. [Templates accepted]",
            "example": "Please check your configuration.yaml.",
        ])
        XCTAssertEqual(service.fields["title"] as? [String: String], [
            "description": "Optional title for your notification. [Optional, Templates accepted]",
            "example": "Test notification",
        ])
        XCTAssertEqual(
            service.fields["notification_id"]?["description"] as? String,
            "Target ID of the notification, will replace a notification with the same ID. [Optional]"
        )
        XCTAssertEqual(
            service.fields["notification_id"]?["example"] as? Int,
            1234
        )

        service = try XCTUnwrap(pers["dismiss"])
        XCTAssertEqual(service.domain, "persistent_notification")
        XCTAssertEqual(service.service, "dismiss")
        XCTAssertEqual(service.domainServicePair, "persistent_notification.dismiss")
        XCTAssertEqual(service.name, "persistent_notification.dismiss", "we modified this")
        XCTAssertEqual(service.description, "Remove a notification from the frontend.")
        XCTAssertEqual(
            service.fields["notification_id"]?["description"] as? String,
            "Target ID of the notification, which should be removed. [Required]"
        )
        XCTAssertEqual(
            service.fields["notification_id"]?["example"] as? Int,
            1234
        )

        service = try XCTUnwrap(pers["mark_read"])
        XCTAssertEqual(service.domain, "persistent_notification")
        XCTAssertEqual(service.service, "mark_read")
        XCTAssertEqual(service.domainServicePair, "persistent_notification.mark_read")
        XCTAssertEqual(service.name, "persistent_notification.mark_read", "we modified this")
        XCTAssertEqual(service.description, "Mark a notification read.")
        XCTAssertEqual(
            service.fields["notification_id"]?["description"] as? String,
            "Target ID of the notification, which should be mark read. [Required]"
        )
        XCTAssertEqual(
            service.fields["notification_id"]?["example"] as? Int,
            1234
        )
    }

    func testGetServicesInvalidResponse() throws {
        let data = HAData.empty
        XCTAssertThrowsError(try HAResponseServices(data: data)) { error in
            XCTAssertEqual(error as? HADataError, .couldntTransform(key: "get_services_root"))
        }
    }
}
