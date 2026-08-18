import Swift

final class EmitterArenaSlice {
    let layout: EmitterStorageLayout
    let storage: ParticleStorage

    private let arena: ParticleArena

    init(
        arena: ParticleArena,
        layout: EmitterStorageLayout,
        storage: ParticleStorage
    ) {
        self.arena = arena
        self.layout = layout
        self.storage = storage
    }
}
