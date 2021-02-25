import Foundation

/// Data from a response
///
/// The root-level information in either the `result` for individual requests or `event` for subscriptions.
public enum HAData: Equatable {
    /// A dictionary response.
    /// - SeeAlso: `get(_:)`and associated methods
    case dictionary([String: Any])
    /// An array response.
    case array([HAData])
    /// Any other response, including `null`
    /// - TODO: Should we expose the actual underlying type here? Are there actually responses that use it?
    case empty

    /// Convert an unknown value type into an enum case
    /// For use with direct response handling.
    ///
    /// - Parameter value: The value to convert
    public init(value: Any?) {
        if let value = value as? [String: Any] {
            self = .dictionary(value)
        } else if let value = value as? [Any] {
            self = .array(value.map(Self.init(value:)))
        } else {
            self = .empty
        }
    }

    public static func == (lhs: HAData, rhs: HAData) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.array(lhsArray), .array(rhsArray)):
            return lhsArray == rhsArray
        case let (.dictionary(lhsDict), .dictionary(rhsDict)):
            // we know the dictionary can be represented in JSON, so take advantage of this fact
            do {
                func serialize(value: [String: Any]) throws -> Data? {
                    enum InvalidObject: Error {
                        case invalidObject
                    }

                    guard JSONSerialization.isValidJSONObject(value) else {
                        // this throws an objective-c exception if it tries to serialize an invalid type
                        throw InvalidObject.invalidObject
                    }

                    return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
                }

                return try serialize(value: lhsDict) == serialize(value: rhsDict)
            } catch {
                return false
            }
        case (.dictionary, .array),
             (.dictionary, .empty),
             (.array, .dictionary),
             (.array, .empty),
             (.empty, .dictionary),
             (.empty, .array):
            return false
        }
    }
}
