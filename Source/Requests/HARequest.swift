import Foundation

/// A request, with data, to be issued
public struct HARequest {
    /// Create a request
    /// - Precondition: data is a JSON-encodable value. From `JSONSerialization` documentation:
    ///     * All objects are `String`, numbers (`Int`, `Float`, etc.), `Array`, `Dictionary`, or `nil`
    ///     * All dictionary keys are `String`
    ///     * Numbers (`Int`, `Float`, etc.) are not `.nan` or `.infinity`
    /// - Parameters:
    ///   - type: The type of the request to issue
    ///   - data: The data to accompany with the request, at the top level
    ///   - queryItems: Query items to include in the call, for REST requests
    ///   - shouldRetry: Whether to retry the request when a connection change occurs
    ///   - retryDuration: Maximum duration for which retries are allowed. Defaults to 10 seconds. Pass nil for unlimited retries.
    public init(
        type: HARequestType,
        data: [String: Any] = [:],
        queryItems: [URLQueryItem] = [],
        shouldRetry: Bool = true,
        retryDuration: Measurement<UnitDuration>? = .init(value: 10, unit: .seconds)
    ) {
        precondition(JSONSerialization.isValidJSONObject(data))
        self.type = type
        self.data = data
        self.shouldRetry = shouldRetry
        self.queryItems = queryItems
        self.retryDuration = retryDuration
    }

    /// The type of the request to be issued
    public var type: HARequestType
    /// Additional top-level data to include in the request
    public var data: [String: Any]
    /// Whether the request should be retried if the connection closes and reopens
    public var shouldRetry: Bool
    /// For REST requests, any query items to include in the call
    public var queryItems: [URLQueryItem]
    /// Maximum duration for which retries are allowed. If nil, retries indefinitely.
    public var retryDuration: Measurement<UnitDuration>?
}
