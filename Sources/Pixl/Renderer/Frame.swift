import Swift

struct Frame {
    var commands: [RenderCommand] = []
    var sounds: [SoundID] = []

    mutating func prepare() {
        commands.removeAll(keepingCapacity: true)
        sounds.removeAll(keepingCapacity: true)
    }
}
