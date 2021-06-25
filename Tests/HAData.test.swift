@testable import HAKit
import XCTest

internal class HADataTests: XCTestCase {
    func testEquality() {
        let empty = HAData.empty
        let dict = HAData.dictionary([:])
        let array = HAData.array([])

        XCTAssertEqual(empty, empty)
        XCTAssertEqual(dict, dict)
        XCTAssertEqual(array, array)
        XCTAssertNotEqual(empty, dict)
        XCTAssertNotEqual(dict, empty)
        XCTAssertNotEqual(empty, array)
        XCTAssertNotEqual(array, empty)
        XCTAssertNotEqual(array, dict)
        XCTAssertNotEqual(dict, array)

        let invalidDict = HAData.dictionary(["key": UUID()])
        XCTAssertNotEqual(invalidDict, invalidDict)
        XCTAssertNotEqual(invalidDict, dict)
        XCTAssertNotEqual(dict, invalidDict)
    }

    func testDictionary() {
        let data = HAData(value: ["test": true])
        guard case let .dictionary(value) = data else {
            XCTFail("expected dictionary to product dictionary")
            return
        }

        XCTAssertEqual(value["test"] as? Bool, true)
    }

    func testArray() throws {
        let data = HAData(value: [
            ["inner_test": 1],
            ["inner_test": 2],
        ])

        guard case let .array(value) = data else {
            XCTFail("expected array to product array")
            return
        }

        XCTAssertEqual(value.count, 2)
        guard case let .dictionary(value1) = try value.get(throwing: 0),
              case let .dictionary(value2) = try value.get(throwing: 1) else {
            XCTFail("expected dictionary elements")
            return
        }

        XCTAssertEqual(value1["inner_test"] as? Int, 1)
        XCTAssertEqual(value2["inner_test"] as? Int, 2)
    }

    func testEmpty() {
        for value: Any? in [
            true, 3, (), nil,
        ] {
            let data = HAData(value: value)
            switch data {
            case .empty: break // pass
            default: XCTFail("expected empty, got \(data)")
            }
        }
    }

    func testDecodeMissingKey() {
        let value = HAData(value: ["key": "value"])
        XCTAssertThrowsError(try value.decode("missing") as String) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("missing"))
        }
    }

    func testDecodeConvertable() throws {
        let value = HAData(value: ["key": "value"])
        XCTAssertEqual(try value.decode("key"), "value")
    }

    func testDecodeNotConvertable() {
        let value = HAData(value: ["key": false])
        XCTAssertThrowsError(try value.decode("key") as String) { error in
            XCTAssertEqual(error as? HADataError, .incorrectType(
                key: "key",
                expected: String(describing: String.self),
                actual: String(describing: Bool.self)
            ))
        }
    }

    func testDecodeToData() throws {
        let value = HAData(value: ["key": ["value": true]])
        let keyValue: HAData = try value.decode("key")
        guard case let .dictionary(innerValue) = keyValue else {
            XCTFail("expected data wrapping dictionary")
            return
        }
        XCTAssertEqual(innerValue["value"] as? Bool, true)
    }

    func testDecodeToOptionalData() throws {
        let value = HAData(value: ["key": ["value": true]])
        let keyValue: HAData = try XCTUnwrap(value.decode("key") as HAData?)
        guard case let .dictionary(innerValue) = keyValue else {
            XCTFail("expected data wrapping dictionary")
            return
        }
        XCTAssertEqual(innerValue["value"] as? Bool, true)
    }

    func testDecodeToDictionaryOfDataFromNonDictionary() throws {
        let value = HAData(value: ["key": true])

        XCTAssertThrowsError(try value.decode("key") as [String: HAData]) { error in
            XCTAssertEqual(error as? HADataError, .incorrectType(
                key: "key",
                expected: String(describing: [String: HAData].self),
                actual: String(describing: Bool.self)
            ))
        }
    }

    func testDecodeToDictionaryOfData() throws {
        let value = HAData(value: ["key": ["a": true, "b": ["test": true]]])
        let keyValue: [String: HAData] = try value.decode("key")

        if case .empty = keyValue["a"] {
            // pass
        } else {
            XCTFail("expected empty but got \(String(describing: keyValue["a"]))")
        }

        if case let .dictionary(dictionary) = keyValue["b"] {
            XCTAssertEqual(dictionary["test"] as? Bool, true)
        } else {
            XCTFail("expected dictionary, got \(String(describing: keyValue["b"]))")
        }
    }

    func testDecodeToArrayOfData() throws {
        let value = HAData(value: ["key": [["inner": 1], ["inner": 2]]])
        let keyValue: [HAData] = try value.decode("key")
        XCTAssertEqual(try keyValue.get(throwing: 0).decode("inner") as Int, 1)
        XCTAssertEqual(try keyValue.get(throwing: 1).decode("inner") as Int, 2)
    }

    func testDecodeToOptionalArrayOfData() throws {
        let value = HAData(value: ["key": [["inner": 1], ["inner": 2]]])
        let keyValue: [HAData] = try XCTUnwrap(value.decode("key") as [HAData]?)
        XCTAssertEqual(try keyValue.get(throwing: 0).decode("inner") as Int, 1)
        XCTAssertEqual(try keyValue.get(throwing: 1).decode("inner") as Int, 2)
    }

    func testDecodeToDateWithNonDictionary() throws {
        let value = HAData(value: nil)
        XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("some_key"))
        }
    }

    func testDecodeToDateArrayForNonArray() throws {
        let value = HAData(value: ["some_key": true])
        XCTAssertThrowsError(try value.decode("some_key") as [Date]) { error in
            XCTAssertEqual(error as? HADataError, .incorrectType(
                key: "some_key",
                expected: String(describing: [Date].self),
                actual: String(describing: Bool.self)
            ))
        }
    }

    func testDecodeToDateArray() throws {
        let value = HAData(value: ["some_key": [
            "2021-02-23T20:45:39.438088-08:00",
            "2021-02-20T05:14:52.647932+00:00",
        ]])
        let dates: [Date] = try value.decode("some_key")
        XCTAssertEqual(dates.count, 2)
    }

    func testDecodeToDateWithNonString() throws {
        let value = HAData(value: ["some_key": true])
        XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
            XCTAssertEqual(error as? HADataError, .incorrectType(
                key: "some_key",
                expected: String(describing: Date.self),
                actual: String(describing: Bool.self)
            ))
        }
    }

    func testDecodeToDateWithMissingKey() throws {
        let value = HAData(value: [:])
        XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
            XCTAssertEqual(error as? HADataError, .missingKey("some_key"))
        }
    }

    func testDecodeToDateWithMissingFractionalSeconds() throws {
        /*
         We need to do this because if the fractional seconds are exactly 0, Python sends without it:

         >>> dt_util.parse_datetime('2021-03-31T16:30:12.000+00:00').isoformat()
         2021-03-31T16:30:12+00:00
         >>> dt_util.parse_datetime('2021-03-31T16:30:12.001+00:00').isoformat()
         2021-03-31T16:30:12.001000+00:00
         */

        let value = HAData(value: ["some_key": "2021-02-20T05:14:52+00:00"])
        let date: Date = try XCTUnwrap(value.decode("some_key") as Date?)

        let components = Calendar.current.dateComponents(
            in: try XCTUnwrap(TimeZone(identifier: "GMT+0600")),
            from: date
        )
        XCTAssertEqual(components.year, 2021)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 14)
        XCTAssertEqual(components.second, 52)
        XCTAssertEqual(components.nanosecond ?? -1, 0)
    }

    func testDecodeToOptionalDate() throws {
        let value = HAData(value: ["some_key": "2021-02-20T05:14:52.647932+00:00"])
        let date: Date = try XCTUnwrap(value.decode("some_key") as Date?)

        let components = Calendar.current.dateComponents(
            in: try XCTUnwrap(TimeZone(identifier: "GMT+0600")),
            from: date
        )
        XCTAssertEqual(components.year, 2021)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 14)
        XCTAssertEqual(components.second, 52)
        XCTAssertEqual(components.nanosecond ?? -1, 647_000_000, accuracy: 100_000)
    }

    func testDecodeToDate() throws {
        let value = HAData(value: ["some_key": "2021-02-20T05:14:52.647932+00:00"])
        let date: Date = try value.decode("some_key")

        let components = Calendar.current.dateComponents(
            in: try XCTUnwrap(TimeZone(identifier: "GMT+0600")),
            from: date
        )
        XCTAssertEqual(components.year, 2021)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 14)
        XCTAssertEqual(components.second, 52)
        XCTAssertEqual(components.nanosecond ?? -1, 647_000_000, accuracy: 100_000)
    }

    func testDecodeToDateWithInvalidString() throws {
        for dateString in [
            // no milliseconds
            "2021-02-20 05:14:52 +0000",
            // no offset
            "2021-02-20T05:14:52.647932",
            // no time
            "2021-02-20",
        ] {
            let value = HAData(value: ["some_key": dateString])
            XCTAssertThrowsError(try value.decode("some_key") as Date) { error in
                XCTAssertEqual(error as? HADataError, .incorrectType(
                    key: "some_key",
                    expected: String(describing: Date.self),
                    actual: String(describing: String.self)
                ))
            }
        }
    }

    func testDecodeToRawRepresentableImplementation() throws {
        enum TestEnumString: String, HADecodeTransformable {
            case valid
        }

        enum TestEnumInt: Int, HADecodeTransformable {
            case valid
        }

        let validData = HAData(value: ["string": "valid", "int": 0])
        XCTAssertEqual(try validData.decode("string") as TestEnumString, .valid)
        XCTAssertEqual(try validData.decode("int") as TestEnumInt, .valid)

        let invalidData = HAData(value: ["string": 0, "int": "invalid"])
        XCTAssertThrowsError(try invalidData.decode("string") as TestEnumString)
        XCTAssertThrowsError(try invalidData.decode("int") as TestEnumInt)
    }

    func testDecodeWithTransform() throws {
        let value = HAData(value: ["name": "zacwest"])
        let result: Int = try value.decode("name", transform: { (underlying: String) in
            underlying.count
        })
        XCTAssertEqual(result, 7)
    }

    func testDecodeWithThrowingTransform() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertThrowsError(try value.decode("name", transform: { (_: String) in nil }) as Int) { error in
            XCTAssertEqual(error as? HADataError, .couldntTransform(key: "name"))
        }
    }

    func testDecodeWithFallbackWithIncorrectType() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertEqual(value.decode("name", fallback: 3) as Int, 3)
    }

    func testDecodeWithFallbackWithMissingKey() throws {
        let value = HAData(value: [])
        XCTAssertEqual(value.decode("name", fallback: 3) as Int, 3)
    }

    func testDecodeWithFallbackWithValue() throws {
        let value = HAData(value: ["name": "zacwest"])
        XCTAssertEqual(value.decode("name", fallback: "other") as String, "zacwest")
    }
}
