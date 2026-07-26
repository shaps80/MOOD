import Swift

final class _StateLocation<Value> {
    private let invalidate: (() -> Void)?
    var value: Value {
        didSet { invalidate?() }
    }

    init(value: Value, invalidate: (() -> Void)? = nil) {
        self.value = value
        self.invalidate = invalidate
    }
}
