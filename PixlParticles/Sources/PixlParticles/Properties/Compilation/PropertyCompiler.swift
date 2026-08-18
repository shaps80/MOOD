import Swift

struct PropertyCompiler {
    struct Descriptor<Output, LoweredValue>
    where Output: Codable & Equatable & Sendable {
        let defaultValue: Output
        let lower: (InitialValue<Output>) -> LoweredValue
        let effects: (LoweredValue) -> Effects
    }

    struct Result<Value> {
        let value: Value
        let effects: Effects
    }

    struct Effects {
        var storage: Set<EmitterStorageRequirement> = []
        var passes: [EmitterPass] = []

        mutating func formUnion(_ other: Self) {
            storage.formUnion(other.storage)
            for pass in other.passes where !passes.contains(pass) {
                passes.append(pass)
            }
        }
    }

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

    func compile<Output, LoweredValue>(
        _ property: Property<Output>,
        using descriptor: Descriptor<Output, LoweredValue>
    ) -> Result<LoweredValue>
    where Output: Codable & Equatable & Sendable {
        let value = descriptor.lower(
            compileInitialValue(
                property,
                default: descriptor.defaultValue
            )
        )
        return .init(value: value, effects: descriptor.effects(value))
    }
}

extension PropertyCompiler.Descriptor where Output == LoweredValue {
    static func constant(
        default defaultValue: Output,
        validate: @escaping (Output) -> Void = { _ in }
    ) -> Self {
        .init(
            defaultValue: defaultValue,
            lower: { value in
                guard case let .constant(value) = value else {
                    preconditionFailure(
                        "Dynamic lowering has not been integrated yet"
                    )
                }
                validate(value)
                return value
            },
            effects: { _ in .init() }
        )
    }
}
