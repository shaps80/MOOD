import Swift

/// Declares one inferred, read-only semantic input in an input profile.
@propertyWrapper
public struct Binding {
    private let bindings: ContiguousArray<Input.Binding>
    private var input: Input?

    /// Semantic input resolved when the enclosing profile initializes.
    public var wrappedValue: Input {
        guard let input else {
            preconditionFailure("The binding has not been resolved by @InputProfile")
        }
        return input
    }

    /// Declares physical bindings for one generated semantic input.
    /// - Parameter bindings: One or more keyboard, button, or directional-axis bindings.
    public init(_ bindings: Input.Binding...) {
        self.bindings = ContiguousArray(bindings)
    }

    @_documentation(visibility: internal)
    /// Resolves this wrapper into storage owned by a generated profile.
    /// - Parameter profile: Profile that will own the semantic input.
    public mutating func _resolve(in profile: Input.Profile) {
        precondition(input == nil, "The binding has already been resolved")
        input = profile.input(bindings: Array(bindings))
    }
}
