import Swift

struct EmitterCompiler {
    func compile(_ emitter: Emitter) -> CompiledEmitter {
        let properties = PropertyCompiler()
        let velocity = properties.compile(
            emitter.velocity,
            using: .velocity
        )
        let color = properties.compile(
            emitter.color,
            using: .constant(default: .white)
        )
        let size = properties.compile(
            emitter.size,
            using: .constant(default: [1, 2]) { size in
                precondition(
                    size.x.isFinite && size.y.isFinite
                        && size.x >= 0 && size.y >= 0
                )
            }
        )
        let rotation = properties.compile(
            emitter.rotation,
            using: .constant(default: 0) { rotation in
                precondition(rotation.isFinite)
            }
        )
        precondition(
            emitter.position.isEmpty,
            "Position property lowering has not been integrated yet"
        )
        var effects = PropertyCompiler.Effects()
        effects.formUnion(velocity.effects)
        effects.formUnion(color.effects)
        effects.formUnion(size.effects)
        effects.formUnion(rotation.effects)

        return CompiledEmitter(
            storage: .init(
                capacity: emitter.capacity,
                requirements: effects.storage
            ),
            constants: .init(
                spawnRegion: emitter.spawnRegion,
                velocity: velocity.value,
                color: color.value,
                size: size.value,
                rotation: rotation.value
            ),
            passes: [.spawn] + effects.passes,
            renderers: emitter.renderers
        )
    }
}
