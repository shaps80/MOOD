import Swift

final class ParticleArena {
    let storage: ParticleStorage

    init(
        layout: EmitterStorageLayout,
        particleAt: (Int) -> Particle
    ) {
        storage = ParticleStorage(
            count: layout.capacity,
            storesVelocity: layout.velocities != nil,
            particleAt: particleAt
        )
    }

    func slice(layout: EmitterStorageLayout) -> EmitterArenaSlice {
        EmitterArenaSlice(
            arena: self,
            layout: layout,
            storage: storage
        )
    }
}
