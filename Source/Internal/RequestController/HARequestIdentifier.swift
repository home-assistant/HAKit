internal struct HARequestIdentifier: RawRepresentable, Hashable, ExpressibleByIntegerLiteral {
    let rawValue: Int

    init(integerLiteral value: Int) {
        self.rawValue = value
    }

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
