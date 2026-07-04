import Swift

enum LifecycleCommand {
    case spawn(any Entity.Type, Vec2, CoordinateSpace)
    case despawn(EntityID)
}

final class FrameEvents {
    var sounds: [SoundID] = []
    var lifecycleCommands: [LifecycleCommand] = []

    func prepare() {
        sounds.removeAll(keepingCapacity: true)
        lifecycleCommands.removeAll(keepingCapacity: true)
    }

    func drainSounds() -> [SoundID] {
        defer {
            sounds.removeAll(keepingCapacity: true)
        }

        return sounds
    }

    func drainLifecycleCommands() -> [LifecycleCommand] {
        defer {
            lifecycleCommands.removeAll(keepingCapacity: true)
        }

        return lifecycleCommands
    }
}

struct Frame {
    var commands: [RenderCommand] = []
    let events = FrameEvents()

    mutating func prepare() {
        commands.removeAll(keepingCapacity: true)
        events.prepare()
    }
}
