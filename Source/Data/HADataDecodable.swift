import Foundation

/// A type which can be decoded using our data type
///
/// - Note: This differs from `Decodable` intentionally; `Decodable` does not support `Any` types or JSON well when the
///         results are extremely dynamic. This limitation requires that we do it ourselves.
public protocol HADataDecodable {
    // one day, if Decodable can handle 'Any' types well, this can be init(decoder:)
    init(data: HAData) throws
}

/// Parse error
public enum HADataError: Error, Equatable {
    case missingKey(String)
    case incorrectType(key: String, expected: String, actual: String)
    case couldntTransform(key: String)
}

public extension HAData {
    /// Convenience access to the dictionary case for a particular key, with an expected type
    ///
    /// - Parameter key: The key to look up in `dictionary` case
    /// - Returns: The value from the dictionary
    /// - Throws: If the key was not present in the dictionary or the type was not the expected type or convertable
    func decode<T>(_ key: String) throws -> T {
        guard case let .dictionary(dictionary) = self, let value = dictionary[key] else {
            throw HADataError.missingKey(key)
        }

        if let value = value as? T {
            return value
        }

        if T.self == HAData.self || T.self == HAData?.self {
            // TODO: can i do this type-safe
            // swiftlint:disable:next force_cast
            return HAData(value: value) as! T
        }

        if T.self == [HAData].self || T.self == [HAData]?.self,
           let value = value as? [Any] {
            // TODO: can i do this type-safe
            // swiftlint:disable:next force_cast
            return value.map(HAData.init(value:)) as! T
        }

        if T.self == Date.self || T.self == Date?.self,
           let value = value as? String,
           let date = Self.formatter.date(from: value) {
            // TODO: can i do this type-safe
            // swiftlint:disable:next force_cast
            return date as! T
        }

        throw HADataError.incorrectType(
            key: key,
            expected: String(describing: T.self),
            actual: String(describing: type(of: value))
        )
    }

    /// Convenience access to the dictionary case for a particular key, with an expected type, with a transform applied
    ///
    /// - Parameter key: The key to look up in `dictionary` case
    /// - Returns: The value from the dictionary
    /// - Throws: If the key was not present in the dictionary or the type was not the expected type or the value couldn't be transformed
    func decode<Value, Transform>(_ key: String, transform: (Value) throws -> Transform?) throws -> Transform {
        let base: Value = try decode(key)

        guard let transformed = try transform(base) else {
            throw HADataError.couldntTransform(key: key)
        }

        return transformed
    }

    /// Convenience access to the dictionary case for a particular key, with an expected type
    ///
    /// - Parameter key: The key to look up in `dictionary` case
    /// - Parameter fallback: The fallback value to use if not found in the dictionary
    /// - Returns: The value from the dictionary
    func decode<T>(_ key: String, fallback: @autoclosure () -> T) -> T {
        guard let value: T = try? decode(key) else {
            return fallback()
        }

        return value
    }

    /// Date formatter
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()
}
