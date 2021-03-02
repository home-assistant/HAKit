import Dispatch

internal class HAResetLock<Value> {
    private let lock = DispatchSemaphore(value: 1)
    private var value: Value?

    init(value: Value?) {
        self.value = value
    }

    func reset() {
        lock.wait()
        defer { lock.signal() }
        value = nil
    }

    func read() -> Value? {
        lock.wait()
        defer { lock.signal() }
        return value
    }

    func pop() -> Value? {
        lock.wait()
        defer { lock.signal() }
        defer { value = nil }
        return value
    }
}
