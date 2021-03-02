/// Configuration of the connection
public struct HAConnectionConfiguration {
    /// Create a new configuration
    /// - Parameters:
    ///   - connectionInfo: Block which provides the connection info on demand
    ///   - fetchAuthToken: Block which invokes a closure asynchronously to provide authentication access tokens
    public init(
        connectionInfo: @escaping () -> HAConnectionInfo?,
        fetchAuthToken: @escaping (@escaping (Result<String, Error>) -> Void) -> Void
    ) {
        self.connectionInfo = connectionInfo
        self.fetchAuthToken = fetchAuthToken
    }

    /// The connection info provider block
    public var connectionInfo: () -> HAConnectionInfo?
    /// The auth token provider block
    public var fetchAuthToken: (_ completion: @escaping (Result<String, Error>) -> Void) -> Void
}
