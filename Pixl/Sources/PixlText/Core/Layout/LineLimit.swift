package struct LineLimit: Hashable, Sendable {
    package var minimum: UInt
    package var maximum: UInt

    package init(minimum: UInt = 0, maximum: UInt = 0) {
        self.minimum = minimum
        self.maximum = maximum
    }

    var isValid: Bool {
        maximum == 0 || minimum <= maximum
    }
}
