import Swift

struct EmitterCompiler {
    func compile(_ emitter: Emitter) -> CompiledEmitter {
        let storesVelocity = emitter.velocity.requiresStorage
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
                position: emitter.position,
                velocity: emitter.velocity,
                color: emitter.color,
                size: emitter.size,
                rotation: emitter.rotation
            ),
            passes: passes,
            renderers: emitter.renderers
        )
    }
}
