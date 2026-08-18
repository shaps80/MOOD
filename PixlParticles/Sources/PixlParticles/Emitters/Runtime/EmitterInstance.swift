import Swift

final class EmitterInstance {
    enum Reconfiguration: Equatable {
        case reusedArena
        case rebuiltArena
    }

    private(set) var compiled: CompiledEmitter
    private(set) var aliveCount = 0
    private(set) var spawnAccumulator: Double = 0
    private(set) var nextParticleID: Particle.ID = 0

    private var arena: EmitterArena

    init(compiled: CompiledEmitter) {
        self.compiled = compiled
        arena = EmitterArena(layout: compiled.storage)
    }

    convenience init(emitter: Emitter) {
        self.init(compiled: EmitterCompiler().compile(emitter))
    }

    @discardableResult
    func apply(_ compiled: CompiledEmitter) -> Reconfiguration {
        guard self.compiled.storage != compiled.storage else {
            self.compiled = compiled
            return .reusedArena
        }

        self.compiled = compiled
        arena = EmitterArena(layout: compiled.storage)
        aliveCount = 0
        spawnAccumulator = 0
        nextParticleID = 0
        return .rebuiltArena
    }

    var arenaIdentity: ObjectIdentifier {
        ObjectIdentifier(arena)
    }

    var arenaByteCount: Int {
        arena.storage.byteCount
    }
}
