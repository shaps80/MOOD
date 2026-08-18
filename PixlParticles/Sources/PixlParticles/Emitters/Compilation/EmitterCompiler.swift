import Swift

struct EmitterCompiler {
    func compile(_ emitter: Emitter) -> CompiledEmitter {
        let velocity = compileVelocity(emitter.velocity)
        let storesVelocity = velocity.requiresStorage
        precondition(
            emitter.position.isEmpty,
            "Position property lowering has not been integrated yet"
        )
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
                color: compileColor(emitter.color),
                size: compileSize(emitter.size),
                rotation: compileRotation(emitter.rotation)
            ),
            passes: passes,
            renderers: emitter.renderers
        )
    }

    private func compileVelocity(
        _ property: Property<Vec3>
    ) -> CompiledEmitter.Velocity {
        guard let modifier = property.last else { return .stationary }
        precondition(
            property.count == 1
                && modifier.operation == .set
                && modifier.variesWith == nil,
            "Velocity modifier lowering has not been integrated yet"
        )

        switch modifier.value {
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

    private func compileColor(_ property: Property<Color>) -> Color {
        guard let modifier = property.last else { return .white }
        precondition(
            property.count == 1
                && modifier.operation == .set
                && modifier.variesWith == nil,
            "Color modifier lowering has not been integrated yet"
        )
        guard case let .constant(color) = modifier.value else {
            preconditionFailure(
                "Dynamic color lowering has not been integrated yet"
            )
        }
        return color
    }

    private func compileSize(_ property: Property<Vec2>) -> Vec2 {
        let size = compileConstant(property, named: "Size", default: [1, 2])
        precondition(
            size.x.isFinite && size.y.isFinite && size.x >= 0 && size.y >= 0
        )
        return size
    }

    private func compileRotation(_ property: Property<Float>) -> Float {
        let rotation = compileConstant(
            property,
            named: "Rotation",
            default: 0
        )
        precondition(rotation.isFinite)
        return rotation
    }

    private func compileConstant<Value>(
        _ property: Property<Value>,
        named name: StaticString,
        default defaultValue: Value
    ) -> Value
    where Value: Codable & Equatable & Sendable {
        guard let modifier = property.last else { return defaultValue }
        precondition(
            property.count == 1
                && modifier.operation == .set
                && modifier.variesWith == nil,
            "\(name) modifier lowering has not been integrated yet"
        )
        guard case let .constant(value) = modifier.value else {
            preconditionFailure(
                "Dynamic \(name) lowering has not been integrated yet"
            )
        }
        return value
    }
}
