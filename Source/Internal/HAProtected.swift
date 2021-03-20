import Foundation

internal class HAProtected<ValueType> {
    private var value: ValueType
    private let lock: os_unfair_lock_t = {
        let value = os_unfair_lock_t.allocate(capacity: 1)
        value.initialize(to: os_unfair_lock())
        return value
    }()

    init(value: ValueType) {
        self.value = value
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    @discardableResult
    func mutate<HandlerType>(using handler: (inout ValueType) -> HandlerType) -> HandlerType {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return handler(&value)
    }

    func read<T>(_ handler: (ValueType) -> T) -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return handler(value)
    }
}
