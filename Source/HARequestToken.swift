/// A token representing an individual request or subscription
///
/// You do not need to strongly retain this value. Requests are only cancelled explicitly.
public protocol HACancellable {
    /// Cancel the request or subscription represented by this.
    func cancel()
}
