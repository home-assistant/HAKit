/// A token representing an individual request or subscription
///
/// You do not need to strongly retain this value. Requests are only cancelled explicitly.
public protocol HACancellable {
    func cancel()
}
