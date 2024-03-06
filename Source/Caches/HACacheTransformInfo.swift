/// Information about a state change which needs transform
public struct HACacheTransformInfo<IncomingType, OutgoingType> {
    /// The value coming into this state change
    /// For populate transforms, this is the request's response
    /// For subscribe transforms, this is the subscription's event value
    public var incoming: IncomingType

    /// The current value of the cache
    /// For populate transforms, this is nil if an initial request hasn't been sent yet and the cache not reset.
    /// For subscribe transforms, this is nil if the populate did not produce results (or does not exist).
    public var current: OutgoingType

    /// The current phase of the subscription
    public var subscriptionPhase: HACacheSubscriptionPhase = .initial
}

/// The subscription phases
public enum HACacheSubscriptionPhase {
    /// `Initial` means it's the first time a value is returned
    case initial
    /// `Iteration` means subsequent iterations
    case iteration
}
