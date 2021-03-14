import Foundation

/// Decode a value by massagging into another type
///
/// For example, this allows decoding a Date from a String without having to do intermediate casting in calling code.
public protocol HADecodeTransformable {
    /// Convert some value to the expected value
    /// - Parameter value: The value to decode
    /// - Throws: If the value contained errors preventing transform
    /// - Returns: An instance from value -- nil allowed
    static func decode(unknown value: Any) throws -> Self?
}

// MARK: - Containers

extension Optional: HADecodeTransformable where Wrapped: HADecodeTransformable {
    /// Transforms any transformable item into an Optional version
    /// - Parameter value: The value to be converted
    /// - Throws: If the underlying decode throws
    /// - Returns: An Optional-wrapped transformed value
    public static func decode(unknown value: Any) throws -> Self? {
        try Wrapped.decode(unknown: value)
    }
}

extension Array: HADecodeTransformable where Element: HADecodeTransformable {
    /// Transforms any array of transformable items
    /// - Parameter value: The array of values to convert
    /// - Throws: If the underlying decode throws
    /// - Returns: The array of values converted, compacted to remove any failures
    public static func decode(unknown value: Any) throws -> Self? {
        guard let value = value as? [Any] else { return nil }
        return try value.compactMap { try Element.decode(unknown: $0) }
    }
}

extension Dictionary: HADecodeTransformable where Key == String, Value: HADecodeTransformable {
    /// Transforms a dictionary whose values are transformable items
    /// - Parameter value: The dictionary with values to be transformed
    /// - Throws: If the underlying decode throws
    /// - Returns: The dictionary of values converted, compacted to remove any failures
    public static func decode(unknown value: Any) throws -> Self? {
        guard let value = value as? [String: Any] else { return nil }
        return try value.compactMapValues { try Value.decode(unknown: $0) }
    }
}

// MARK: - Values

extension HAData: HADecodeTransformable {
    /// Allows HAData to be transformed from any underlying value
    /// - Parameter value: Any value
    /// - Returns: The `HAData`-wrapped version of the value
    public static func decode(unknown value: Any) -> Self? {
        Self(value: value)
    }
}

extension Date: HADecodeTransformable {
    /// Date formatter
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()

    /// Converts from ISO 8601 (with milliseconds) String to Date
    /// - Parameter value: A string value to convert
    /// - Returns: The value converted to a Date, or nil if not possible
    public static func decode(unknown value: Any) -> Self? {
        guard let value = value as? String else { return nil }
        return Self.formatter.date(from: value)
    }
}

public extension HADecodeTransformable where Self: RawRepresentable {
    /// Converts from an unknown value to this raw representable type
    /// - Parameter value: The value to attempt to convert
    /// - Returns: The value transformed, if it is of the right type and init succeeds
    static func decode(unknown value: Any) -> Self? {
        guard let value = value as? RawValue else { return nil }
        return Self(rawValue: value)
    }
}
