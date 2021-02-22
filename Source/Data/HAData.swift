/// Data from a response
///
/// The root-level information in either the `result` for individual requests or `event` for subscriptions.
public enum HAData {
    /// A dictionary response.
    /// - SeeAlso: `get(_:)`and associated methods
    case dictionary([String: Any])
    /// An array response.
    case array([HAData])
    /// Any other response, including `null`
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
}
