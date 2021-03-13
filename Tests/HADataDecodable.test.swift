import HAKit
import XCTest

internal class HADataDecodableTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RandomDecodable.shouldThrow = false
    }

    func testArrayDecodableSuccess() throws {
        let data = HAData.array([.empty, .empty, .empty])
        let result = try [RandomDecodable].init(data: data)
        XCTAssertEqual(result.count, 3)
    }

    func testArrayDecodableFailureDueToRootData() {
        let data = HAData.dictionary(["key": "value"])
        XCTAssertThrowsError(try [RandomDecodable].init(data: data)) { error in
            XCTAssertEqual(error as? HADataError, .couldntTransform(key: "root"))
        }
    }

    func testArrayDecodableFailureDueToInside() throws {
        RandomDecodable.shouldThrow = true
        let data = HAData.array([.empty, .empty, .empty])
        XCTAssertThrowsError(try [RandomDecodable].init(data: data)) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("any"))
        }
    }
}

private class RandomDecodable: HADataDecodable {
    static var shouldThrow = false
    required init(data: HAData) throws {
        if Self.shouldThrow {
            throw HADataError.missingKey("any")
        }
    }
}
