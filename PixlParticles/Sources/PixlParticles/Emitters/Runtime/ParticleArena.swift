import Swift

final class ParticleArena {
    let storage: ParticleStorage

    init(
        layout: EmitterStorageLayout,
        velocityPacking: PackedVector3,
        palette: ParticleColorPalette
    ) {
        storage = ParticleStorage(
            capacity: layout.capacity,
            storesVelocity: layout.velocities != nil,
            velocityPacking: velocityPacking,
            palette: palette
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
