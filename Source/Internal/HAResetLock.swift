import Dispatch

internal class HAResetLock<Value> {
    private var value: HAProtected<Value?>

    init(value: Value?) {
        self.value = .init(value: value)
    }

    func reset() {
        value.mutate { value in
            value = nil
        }
    }

    func read() -> Value? {
        value.read { $0 }
    }

    func pop() -> Value? {
        value.mutate { value in
            let old = value
            value = nil
            return old
        }
    }
}
