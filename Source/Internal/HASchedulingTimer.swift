import Foundation

@propertyWrapper
internal struct HASchedulingTimer<WrappedValue: Timer> {
    var wrappedValue: WrappedValue? {
        willSet {
            if wrappedValue != newValue {
                wrappedValue?.invalidate()
            }
        }

        didSet {
            if let timer = wrappedValue, timer != oldValue {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
}
