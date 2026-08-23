import PixlRenderer
import Swift

public final class EmitterInstance {
    enum Reconfiguration: Equatable {
        case reusedArena
        case rebuiltArena
    }

    private(set) var compiled: CompiledEmitter
    private(set) var spawnAccumulator: UInt64 = 0

    private let random: RandomSource
    private var arena: ParticleArena
    private var slice: EmitterArenaSlice
    private var metadata: Metadata

    init(
        compiled: CompiledEmitter,
        random: RandomSource = .init(seed: 0),
        storesRewindState: Bool = true
    ) {
        self.compiled = compiled
        self.random = random

        metadata = Metadata(
            capacity: compiled.storage.capacity,
            count: 0
        )
        let arena = Self.makeArena(compiled: compiled)
        self.arena = arena
        slice = arena.slice(layout: compiled.storage)
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
            reset()
            return .reusedArena
        }

        self.compiled = compiled
        metadata = Metadata(
            capacity: compiled.storage.capacity,
            count: 0
        )
        arena = Self.makeArena(compiled: compiled)
        slice = arena.slice(layout: compiled.storage)
        spawnAccumulator = 0
        return .rebuiltArena
    }

    func advance(by delta: Float) {
        var spawnCount = scheduledSpawnCount()
        slice.storage.advanceLifetimes()

        var index = slice.storage.count
        while index > 0 {
            index -= 1
            guard slice.storage.isDead(at: index) else { continue }

            if spawnCount > 0 {
                recycle(at: index)
                spawnCount -= 1
            } else {
                remove(at: index)
            }
        }

        while spawnCount > 0 {
            appendSpawn()
            spawnCount -= 1
        }

        slice.storage.advance(by: delta)
    }

    func reset() {
        metadata.reset(count: 0)
        slice.storage.removeAll()
        spawnAccumulator = 0
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
    }

    @discardableResult
    func spawn() -> Particle.ID? {
        let index = slice.storage.count
        guard index < slice.storage.capacity else { return nil }
        guard let allocated = metadata.allocate(at: index) else { return nil }

        append(allocated)
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

    @inline(__always)
    private func scheduledSpawnCount() -> Int {
        let sum = spawnAccumulator + compiled.constants.spawnRate.remainder
        if sum >= compiled.constants.spawnRate.denominator {
            spawnAccumulator = sum - compiled.constants.spawnRate.denominator
            return Int(compiled.constants.spawnRate.whole) + 1
        }
        spawnAccumulator = sum
        return Int(compiled.constants.spawnRate.whole)
    }

    @inline(__always)
    private func recycle(at index: Int) {
        let slot = slice.storage.slot(at: index)
        let id = metadata.recycle(slot, at: index)
        let particle = Self.spawn(
            id: id,
            random: random,
            constants: compiled.constants
        )
        if compiled.storage.velocities == nil {
            slice.storage.replaceStationary(
                at: index,
                with: particle,
                slot: slot,
                lifetimeTicks: compiled.constants.lifetimeTicks
            )
        } else {
            slice.storage.replaceMoving(
                at: index,
                with: particle,
                slot: slot,
                lifetimeTicks: compiled.constants.lifetimeTicks
            )
        }
    }

    @inline(__always)
    private func appendSpawn() {
        let allocated = metadata.allocateAvailable(at: slice.storage.count)
        append(allocated)
    }

    @inline(__always)
    private func append(_ allocated: (slot: UInt32, id: Particle.ID)) {
        let particle = Self.spawn(
            id: allocated.id,
            random: random,
            constants: compiled.constants
        )
        if compiled.storage.velocities == nil {
            slice.storage.appendStationary(
                particle,
                slot: allocated.slot,
                lifetimeTicks: compiled.constants.lifetimeTicks
            )
        } else {
            slice.storage.appendMoving(
                particle,
                slot: allocated.slot,
                lifetimeTicks: compiled.constants.lifetimeTicks
            )
        }
    }

    private static func makeArena(compiled: CompiledEmitter) -> ParticleArena {
        ParticleArena(layout: compiled.storage)
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
