/// A request which has a strongly-typed response format
public struct HATypedRequest<ResponseType: HADataDecodable> {
    /// Create a typed request
    /// - Parameter request: The request to be issued
    public init(request: HARequest) {
        self.request = request
    }

    /// The request to be issued
    public var request: HARequest
}
