/// Information about a state change which needs transform
public struct HACacheTransformInfo<IncomingType, OutgoingType> {
    /// The value coming into this state change
    /// For populate transforms, this is the request's response
    /// For subscribe transforms, this is the subscription's event value
    public var incoming: IncomingType

    /// The current value of the cache
    /// For populate transforms, this is nil if an initial request hasn't been sent yet and the cache not reset.
    /// For subscribe transforms, this is non-optional.
    public var current: OutgoingType
}
