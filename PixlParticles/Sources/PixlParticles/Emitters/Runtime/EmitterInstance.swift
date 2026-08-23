import PixlRenderer
import Swift

public final class EmitterInstance {
    enum Reconfiguration: Equatable {
        case reusedArena
        case rebuiltArena
    }

    private(set) var compiled: CompiledEmitter
    private(set) var spawnAccumulator: Double = 0

    private let random: RandomSource
    private let storesRewindState: Bool
    private var arena: ParticleArena
    private var slice: EmitterArenaSlice
    private var metadata: Metadata
    private var initialState: InitialParticleState?
    private var topologyChanged = false

    init(
        compiled: CompiledEmitter,
        random: RandomSource = .init(seed: 0),
        storesRewindState: Bool = true
    ) {
        self.compiled = compiled
        self.random = random
        self.storesRewindState = storesRewindState

        metadata = Metadata(
            capacity: compiled.storage.capacity,
            count: compiled.storage.capacity
        )
        let arena = Self.makeArena(compiled: compiled, random: random)
        self.arena = arena
        slice = arena.slice(layout: compiled.storage)
        initialState = storesRewindState ? slice.storage.initialState() : nil
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
        metadata = Metadata(
            capacity: compiled.storage.capacity,
            count: compiled.storage.capacity
        )
        arena = Self.makeArena(compiled: compiled, random: random)
        slice = arena.slice(layout: compiled.storage)
        initialState = storesRewindState ? slice.storage.initialState() : nil
        spawnAccumulator = 0
        topologyChanged = false
        return .rebuiltArena
    }

    func advance(by delta: Float) {
        slice.storage.advance(by: delta)
    }

    func reset() {
        if topologyChanged {
            metadata = Metadata(
                capacity: compiled.storage.capacity,
                count: compiled.storage.capacity
            )
            arena = Self.makeArena(compiled: compiled, random: random)
            slice = arena.slice(layout: compiled.storage)
            initialState = storesRewindState ? slice.storage.initialState() : nil
        } else if let initialState {
            slice.storage.restore(from: initialState)
        } else {
            arena = Self.makeArena(compiled: compiled, random: random)
            slice = arena.slice(layout: compiled.storage)
        }
        topologyChanged = false
    }

    func resetInterpolation() {
        slice.storage.resetInterpolation()
    }

    func particles() -> [Particle] {
        slice.storage.particles { metadata.id(for: $0) }
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try slice.storage.withRenderingData(body)
    }

    @discardableResult
    func remove(_ id: Particle.ID) -> Bool {
        guard let removed = metadata.resolve(id) else { return false }
        remove(slot: removed.slot, at: removed.index)
        return true
    }

    @inline(__always)
    func remove(at index: Int) {
        remove(slot: slice.storage.slot(at: index), at: index)
    }

    @inline(__always)
    private func remove(slot: UInt32, at index: Int) {
        let movedSlot: UInt32?
        if compiled.storage.velocities == nil {
            movedSlot = slice.storage.removeStationary(at: index)
        } else {
            movedSlot = slice.storage.removeMoving(at: index)
        }

        if let movedSlot {
            metadata.move(movedSlot, to: index)
        }

        metadata.release(slot)
        topologyChanged = true
    }

    @discardableResult
    func spawn() -> Particle.ID? {
        let index = slice.storage.count
        guard index < slice.storage.capacity else { return nil }
        guard let allocated = metadata.allocate(at: index) else { return nil }

        let particle = Self.spawn(
            id: allocated.id,
            random: random,
            constants: compiled.constants
        )
        if compiled.storage.velocities == nil {
            slice.storage.appendStationary(
                particle,
                slot: allocated.slot
            )
        } else {
            slice.storage.appendMoving(
                particle,
                slot: allocated.slot
            )
        }

        topologyChanged = true
        return allocated.id
    }

    var aliveCount: Int {
        slice.storage.count
    }

    var arenaIdentity: ObjectIdentifier {
        ObjectIdentifier(slice)
    }

    var arenaByteCount: Int {
        slice.layout.byteCount + metadata.byteCount
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
