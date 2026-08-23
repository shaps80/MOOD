import Swift

final class ParticleArena {
    let storage: ParticleStorage

    init(
        layout: EmitterStorageLayout
    ) {
        storage = ParticleStorage(
            capacity: layout.capacity,
            storesVelocity: layout.velocities != nil
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
