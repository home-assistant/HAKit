import Foundation

/// Namespace entrypoint of the library
public enum HAKit {
    /// Create a new connection
    /// - Parameters:
    ///   - configuration: The configuration for the connection
    ///   - connectAutomatically: Defaults to `true`. Whether to call .connect() automatically.
    ///   - urlSession: Optional custom URLSession for REST API calls. When provided, this session
    ///                 will be used for all REST API requests (e.g., requests with `.rest()` type).
    ///                 This is useful for handling custom certificate validation or client certificate
    ///                 authentication (mTLS). If not provided, a default ephemeral session is used.
    ///                 Note: This only affects REST API calls, not WebSocket connections.
    /// - Returns: The connection itself
    public static func connection(
        configuration: HAConnectionConfiguration,
        connectAutomatically: Bool = true,
        urlSession: URLSession? = nil
    ) -> HAConnection {
        HAConnectionImpl(
            configuration: configuration,
            urlSession: urlSession ?? .init(configuration: .ephemeral),
            connectAutomatically: connectAutomatically
        )
    }
}
