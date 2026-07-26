import Swift

@propertyWrapper @dynamicMemberLookup
public struct Binding<Value> {
    private let read: () -> Value
    private let write: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        read = get
        write = set
    }

    public static func constant(_ value: Value) -> Self {
        .init(get: { value }, set: { _ in })
    }

    public var wrappedValue: Value {
        get { read() }
        nonmutating set { write(newValue) }
    }

    public var projectedValue: Self { self }

    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        .init(
            get: { read()[keyPath: keyPath] },
            set: { value in
                var root = read()
                root[keyPath: keyPath] = value
                write(root)
            }
        )
    }
}
