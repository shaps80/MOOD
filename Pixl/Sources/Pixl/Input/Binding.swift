import Swift

/// Declares one inferred, read-only semantic input in an input profile.
@propertyWrapper
public struct Binding {
    private let bindings: ContiguousArray<Input.Binding>
    private var input: Input?

    public var wrappedValue: Input {
        guard let input else {
            preconditionFailure("The binding has not been resolved by @InputProfile")
        }
        return input
    }

    public init(_ bindings: Input.Binding...) {
        self.bindings = ContiguousArray(bindings)
    }

    @_documentation(visibility: internal)
    public mutating func _resolve(in profile: Input.Profile) {
        precondition(input == nil, "The binding has already been resolved")
        input = profile.input(bindings: Array(bindings))
    }
}
