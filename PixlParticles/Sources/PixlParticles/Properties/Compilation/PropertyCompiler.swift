import Swift

struct PropertyCompiler {
    enum InitialValue<Output>
    where Output: Codable & Equatable & Sendable {
        case constant(Output)
        case random(
            from: Output,
            to: Output,
            variation: Property<Output>.RandomVariation
        )
        case curve([Property<Output>.Keyframe])
    }

    func compileInitialValue<Output>(
        _ property: Property<Output>,
        default defaultValue: Output
    ) -> InitialValue<Output>
    where Output: Codable & Equatable & Sendable {
        guard let modifier = property.last else {
            return .constant(defaultValue)
        }
        precondition(
            property.count == 1
                && modifier.operation == .set
                && modifier.variesWith == nil,
            "Modifier lowering has not been integrated yet"
        )

        switch modifier.value {
        case let .constant(value):
            return .constant(value)
        case let .random(from, to, variation):
            return .random(from: from, to: to, variation: variation)
        case let .curve(keyframes):
            return .curve(keyframes)
        }
    }

    func compileConstant<Output>(
        _ property: Property<Output>,
        default defaultValue: Output
    ) -> Output
    where Output: Codable & Equatable & Sendable {
        guard case let .constant(value) = compileInitialValue(
            property,
            default: defaultValue
        ) else {
            preconditionFailure("Dynamic lowering has not been integrated yet")
        }
        return value
    }
}
