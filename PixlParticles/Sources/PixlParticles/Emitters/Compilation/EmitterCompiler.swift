import Swift

struct EmitterCompiler {
    func compile(_ emitter: Emitter) -> CompiledEmitter {
        let properties = PropertyCompiler()
        let velocity = compileVelocity(
            properties.compileInitialValue(emitter.velocity, default: .zero)
        )
        let storesVelocity = velocity.requiresStorage
        let size = properties.compileConstant(emitter.size, default: [1, 2])
        let rotation = properties.compileConstant(
            emitter.rotation,
            default: 0
        )
        precondition(
            emitter.position.isEmpty,
            "Position property lowering has not been integrated yet"
        )
        precondition(
            size.x.isFinite && size.y.isFinite && size.x >= 0 && size.y >= 0
        )
        precondition(rotation.isFinite)
        var passes: [EmitterPass] = [.spawn]
        if storesVelocity {
            passes.append(.integratePosition)
        }

        return CompiledEmitter(
            storage: .init(
                capacity: emitter.capacity,
                storesVelocity: storesVelocity
            ),
            constants: .init(
                spawnRegion: emitter.spawnRegion,
                velocity: velocity,
                color: properties.compileConstant(
                    emitter.color,
                    default: .white
                ),
                size: size,
                rotation: rotation
            ),
            passes: passes,
            renderers: emitter.renderers
        )
    }

    private func compileVelocity(
        _ value: PropertyCompiler.InitialValue<Vec3>
    ) -> CompiledEmitter.Velocity {
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
    }
}
