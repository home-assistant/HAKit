@testable import HAKit
import XCTest

internal class HAWebSocketResponseTests: XCTestCase {
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
        XCTAssertThrowsError(try HAWebSocketResponse(
            dictionary: HAWebSocketResponseFixture
                .responseMissingID
        )) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownId: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testInvalidID() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(
            dictionary: HAWebSocketResponseFixture
                .responseInvalidID
        )) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownId: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testMissingType() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(
            dictionary: HAWebSocketResponseFixture
                .responseMissingType
        )) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownType: break // pass
            default: XCTFail("expected different error")
            }
        }
    }

    func testInvalidType() throws {
        XCTAssertThrowsError(try HAWebSocketResponse(
            dictionary: HAWebSocketResponseFixture
                .responseInvalidType
        )) { error in
            switch error as? HAWebSocketResponse.ParseError {
            case .unknownType: break // pass
            default: XCTFail("expected different error")
            }
        }
    }
}
