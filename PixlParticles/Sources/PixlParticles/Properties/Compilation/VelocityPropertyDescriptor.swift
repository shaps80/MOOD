import Swift

extension PropertyCompiler.Descriptor
where Output == Vec3, LoweredValue == CompiledEmitter.Velocity {
    static var velocity: Self {
        Self(
            defaultValue: .zero,
            lower: { value in
                switch value {
                case let .constant(value):
                    precondition(
                        value == .zero,
                        "Constant velocity lowering has not been integrated yet"
                    )
                    return .stationary
                case let .random(from, to, variation):
                    precondition(
                        from.x.isFinite && from.y.isFinite && from.z.isFinite
                            && to.x.isFinite && to.y.isFinite && to.z.isFinite
                            && from.x <= to.x && from.y <= to.y && from.z <= to.z
                    )
                    if from == .zero && to == .zero {
                        return .stationary
                    }
                    precondition(
                        variation == .perValue
                            && from.x == from.y && from.y == from.z
                            && to.x == to.y && to.y == to.z,
                        "General random velocity lowering has not been integrated yet"
                    )
                    return .random(from.x ..< to.x)
                case .curve:
                    preconditionFailure(
                        "Velocity curve lowering has not been integrated yet"
                    )
                }
            },
            effects: { velocity in
                velocity.requiresStorage
                    ? .init(
                        storage: [.velocity],
                        passes: [.integratePosition]
                    )
                    : .init()
            }
        )
    }
}
