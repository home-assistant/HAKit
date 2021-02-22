/// A subscription request which has a strongly-typed handler
public struct HATypedSubscription<ResponseType: HADataDecodable> {
    /// Create a typed subscription
    /// - Parameter request: The request to be issued to start the subscription
    public init(request: HARequest) {
        self.request = request
    }

    /// The request to be issued
    public var request: HARequest
}
