import Swift

@_documentation(visibility: internal)
public final class _StateStorage<Value> {
    private let field: String
    private var makeInitialValue: (() -> Value)?
    private var initialValue: Value?
    private var location: _StateLocation<Value>?
    private var isGraphBound = false

    public init(field: String, initialValue: Value) {
        self.field = field
        self.initialValue = initialValue
    }

    public init(field: String, makeInitialValue: @escaping () -> Value) {
        self.field = field
        self.makeInitialValue = makeInitialValue
    }

    public var wrappedValue: Value {
        get { resolve().value }
        set { resolve().value = newValue }
    }

    public var projectedValue: Binding<Value> {
        return .init(
            get: { self.resolve().value },
            set: { self.resolve().value = $0 }
        )
    }

    private func resolve() -> _StateLocation<Value> {
        if let location {
            if !isGraphBound, let context = _StateRuntime.context {
                let graphLocation = context.location(
                    field: field,
                    initialValue: location.value
                )
                self.location = graphLocation
                isGraphBound = true
                return graphLocation
            }
            return location
        }
        let value: Value
        if let initialValue {
            value = initialValue
        } else if let makeInitialValue {
            value = makeInitialValue()
            self.initialValue = value
            self.makeInitialValue = nil
        } else {
            preconditionFailure("State has no initial value")
        }

        let context = _StateRuntime.context
        let location = context?.location(field: field, initialValue: value)
            ?? _StateLocation(value: value)
        self.location = location
        isGraphBound = context != nil
        return location
    }
}
