import Foundation

/// Namespace entrypoint of the library
public enum HAKit {
    /// Create a new connection
    /// - Parameter configuration: The configuration for the connection
    /// - Parameter connectAutomatically: Defaults to `true`. Whether to call .connect() automatically.
    /// - Returns: The connection itself
    public static func connection(
        configuration: HAConnectionConfiguration,
        connectAutomatically: Bool = true
    ) -> HAConnection {
        HAConnectionImpl(
            configuration: configuration,
            connectAutomatically: connectAutomatically
        )
    }
}
