#if SWIFT_PACKAGE
import HAKit
#endif
import PromiseKit

public extension HACache {
    /// Wrap a once subscription in a Guarantee
    ///
    /// - SeeAlso: `HACache.once(_:)`
    /// - Returns: The promies for the value, and a block to cancel
    func once() -> (promise: Guarantee<ValueType>, cancel: () -> Void) {
        let (guarantee, seal) = Guarantee<ValueType>.pending()
        let token = once(seal)
        return (promise: guarantee, cancel: token.cancel)
    }
}
