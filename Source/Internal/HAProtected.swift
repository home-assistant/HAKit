import Foundation

internal class HAProtected<ValueType> {
    private var value: ValueType
    private let queue = DispatchQueue(label: "request-controller-state")

    init(value: ValueType) {
        self.value = value
    }

    func mutate<HandlerType>(
        using handler: @escaping (inout ValueType) -> HandlerType,
        then perform: @escaping (HandlerType) -> Void = { _ in },
        on thenQueue: DispatchQueue = .main
    ) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.async(execute: .init(qos: .default, flags: .barrier, block: { [self] in
            let result = handler(&value)
            thenQueue.async(execute: {
                perform(result)
            })
        }))
    }

    func read<T>(_ handler: (ValueType) -> T) -> T {
        dispatchPrecondition(condition: .notOnQueue(queue))
        return queue.sync {
            let result = handler(value)
            // returning the value out of the protected class is not cool
            assert(result as? ValueType == nil)
            return result
        }
    }
}
