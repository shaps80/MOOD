import PixlRenderer
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

    private let random: RandomSource
    private let storesRewindState: Bool
    private var arena: ParticleArena
    private var slice: EmitterArenaSlice
    private var initialState: InitialParticleState?

    init(
        compiled: CompiledEmitter,
        random: RandomSource = .init(seed: 0),
        storesRewindState: Bool = true
    ) {
        self.compiled = compiled
        self.random = random
        self.storesRewindState = storesRewindState

        let arena = Self.makeArena(compiled: compiled, random: random)
        self.arena = arena
        slice = arena.slice(layout: compiled.storage)
        initialState = storesRewindState ? slice.storage.initialState() : nil
        aliveCount = compiled.storage.capacity
        nextParticleID = Particle.ID(compiled.storage.capacity)
    }

    convenience init(
        emitter: Emitter,
        random: RandomSource = .init(seed: 0),
        storesRewindState: Bool = true
    ) {
        self.init(
            compiled: EmitterCompiler().compile(emitter),
            random: random,
            storesRewindState: storesRewindState
        )
    }

    @discardableResult
    func apply(_ compiled: CompiledEmitter) -> Reconfiguration {
        guard self.compiled.storage != compiled.storage else {
            self.compiled = compiled
            return .reusedArena
        }

        self.compiled = compiled
        arena = Self.makeArena(compiled: compiled, random: random)
        slice = arena.slice(layout: compiled.storage)
        initialState = storesRewindState ? slice.storage.initialState() : nil
        aliveCount = compiled.storage.capacity
        spawnAccumulator = 0
        nextParticleID = Particle.ID(compiled.storage.capacity)
        return .rebuiltArena
    }

    func advance(by delta: Float) {
        slice.storage.advance(by: delta)
    }

    func reset() {
        if let initialState {
            slice.storage.restore(from: initialState)
        } else {
            arena = Self.makeArena(compiled: compiled, random: random)
            slice = arena.slice(layout: compiled.storage)
        }
        nextParticleID = Particle.ID(compiled.storage.capacity)
    }

    func resetInterpolation() {
        slice.storage.resetInterpolation()
    }

    func particles() -> [Particle] {
        slice.storage.particles()
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try slice.storage.withRenderingData(body)
    }

    var arenaIdentity: ObjectIdentifier {
        ObjectIdentifier(slice)
    }

    var arenaByteCount: Int {
        slice.layout.byteCount
    }

    private static func makeArena(
        compiled: CompiledEmitter,
        random: RandomSource
    ) -> ParticleArena {
        ParticleArena(layout: compiled.storage) { index in
            spawn(
                id: Particle.ID(index),
                random: random,
                constants: compiled.constants
            )
        }
    }

    private static func spawn(
        id: Particle.ID,
        random: RandomSource,
        constants: CompiledEmitter.Constants
    ) -> Particle {
        let velocity: Vec3
        switch constants.velocity {
        case .stationary:
            velocity = .zero
        case let .random(range):
            let block = random.block(at: id, channel: .velocity)
            velocity = [
                RandomSource.float(from: block.x0, in: range),
                RandomSource.float(from: block.x1, in: range),
                RandomSource.float(from: block.x2, in: range),
            ]
        }

        return Particle(
            id: id,
            position: constants.spawnRegion.sample(using: random, at: id),
            velocity: velocity,
            color: constants.color
        )
    }

}
