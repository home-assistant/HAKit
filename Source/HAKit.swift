import Foundation

/// Namespace entrypoint of the library
public enum HAKit {
    /// Create a new connection
    /// - Parameter configuration: The configuration for the connection
    /// - Returns: The connection itself
    public static func connection(configuration: HAConnectionConfiguration) -> HAConnection {
        HAConnectionImpl(configuration: configuration)
    }
}
