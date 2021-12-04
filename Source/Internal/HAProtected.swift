import Foundation

/// Wrapper around a value with a lock
///
/// Provided publicly as a convenience in case the library uses it anywhere.
public class HAProtected<ValueType> {
    private var value: ValueType
    private let lock: os_unfair_lock_t = {
        let value = os_unfair_lock_t.allocate(capacity: 1)
        value.initialize(to: os_unfair_lock())
        return value
    }()

    /// Create a new protected value
    /// - Parameter value: The initial value
    public init(value: ValueType) {
        self.value = value
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    /// Get and optionally change the value
    /// - Parameter handler: Will be invoked immediately with the current value as an inout parameter.
    /// - Returns: The value returned by the handler block
    @discardableResult
    public func mutate<HandlerType>(using handler: (inout ValueType) -> HandlerType) -> HandlerType {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return handler(&value)
    }

    /// Read the value and get a result out of it
    /// - Parameter handler: Will be invoked immediately with the current value.
    /// - Returns: The value returned by the handler block
    public func read<T>(_ handler: (ValueType) -> T) -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return handler(value)
    }
}
