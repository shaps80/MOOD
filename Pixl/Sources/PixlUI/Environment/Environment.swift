import Swift

@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        let values = _EnvironmentRuntime.context?.values ?? EnvironmentValues()
        return values[keyPath: keyPath]
    }
}

struct _EnvironmentContext: @unchecked Sendable {
    let values: EnvironmentValues
}

enum _EnvironmentRuntime {
    @TaskLocal static var context: _EnvironmentContext?
}
