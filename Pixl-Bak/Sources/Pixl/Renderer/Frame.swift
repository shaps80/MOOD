import Swift

struct Frame {
    var commands: [RenderCommand] = []
    var sounds: [SoundID] = []

    mutating func prepare() {
        commands.removeAll(keepingCapacity: true)
        sounds.removeAll(keepingCapacity: true)
    }

    mutating func drainSounds() -> [SoundID] {
        defer {
            sounds.removeAll(keepingCapacity: true)
        }

        return sounds
    }
}
