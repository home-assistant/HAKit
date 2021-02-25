@testable import HAWebSocket
import XCTest

class HAWebSocketResponseTests: XCTestCase {
    func testAuthRequired() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.authRequired)
        XCTAssertEqual(response, .auth(.required))
    }

    func testAuthOK() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.authOK)
        XCTAssertEqual(response, .auth(.ok(version: "2021.3.0.dev0")))
    }

    func testAuthOKMissingVersion() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.authOKMissingVersion)
        XCTAssertEqual(response, .auth(.ok(version: "unknown")))
    }

    func testAuthInvalid() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.authInvalid)
        XCTAssertEqual(response, .auth(.invalid))
    }

    func testResponseEmpty() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseEmptyResult)
        XCTAssertEqual(response, .result(identifier: 1, result: .success(.empty)))
    }

    func testResponseDictionary() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseDictionaryResult)
        XCTAssertEqual(response, .result(
            identifier: 2,
            result: .success(.dictionary(["id": "76ce52a813c44fdf80ee36f926d62328"]))
        ))
    }

    func testResponseEvent() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseEvent)
        XCTAssertEqual(response, .event(
            identifier: 5,
            data: .dictionary(["result": "ok"])
        ))
    }

    func testResponseError() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseError)
        XCTAssertEqual(response, .result(identifier: 4, result: .failure(.external(.init(
            code: "unknown_command",
            message: "Unknown command."
        )))))
    }

    func testResponseArray() throws {
        let response = try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseArrayResult)
        XCTAssertEqual(response, .result(
            identifier: 3,
            result: .success(.array([
                .init(value: ["1": true]),
                .init(value: ["2": true]),
                .init(value: ["3": true]),
            ]))
        ))
    }

    func testMissingID() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseMissingID)) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownId: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testInvalidID() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseInvalidID)) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownId: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testMissingType() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseMissingType)) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownType: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testInvalidType() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(dictionary: HAWebSocketResponseFixture.responseInvalidType)) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownType: break // pass
            default: XCTFail("expected different error")
            }
        }
    }
}

private enum HAWebSocketResponseFixture {
    static func JSONIfy(_ value: String) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: value.data(using: .utf8)!, options: []) as! [String: Any]
    }

    static var authRequired = JSONIfy("""
        {"type": "auth_required", "ha_version": "2021.3.0.dev0"}
    """)

    static var authOK = JSONIfy("""
        {"type": "auth_ok", "ha_version": "2021.3.0.dev0"}
    """)

    static var authOKMissingVersion = JSONIfy("""
        {"type": "auth_ok"}
    """)

    static var authInvalid = JSONIfy("""
        {"type": "auth_invalid", "message": "Invalid access token or password"}
    """)

    static var responseEmptyResult = JSONIfy("""
        {"id": 1, "type": "result", "success": true, "result": null}
    """)

    static var responseDictionaryResult = JSONIfy("""
        {"id": 2, "type": "result", "success": true, "result": {"id": "76ce52a813c44fdf80ee36f926d62328"}}
    """)

    static var responseArrayResult = JSONIfy("""
        {"id": 3, "type": "result", "success": true, "result": [{"1": true}, {"2": true}, {"3": true}]}
    """)

    static var responseMissingID = JSONIfy("""
        {"type": "result", "success": "true"}
    """)

    static var responseInvalidID = JSONIfy("""
        {"id": "lol", "type": "result", "success": "true"}
    """)

    static var responseMissingType = JSONIfy("""
        {"id": 9, "success": "true"}
    """)

    static var responseInvalidType = JSONIfy("""
        {"id": 10, "type": "unknown", "success": "true"}
    """)

    static var responseError = JSONIfy("""
        {"id": 4, "type": "result", "success": false, "error": {"code": "unknown_command", "message": "Unknown command."}}
    """)

    static var responseEvent = JSONIfy("""
        {"id": 5, "type": "event", "event": {"result": "ok"}}
    """)
}
