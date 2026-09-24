import PixlRenderer
import Swift

public final class EmitterInstance {
    enum Reconfiguration: Equatable {
        case reusedArena
        case rebuiltArena
    }

    private(set) var compiled: CompiledEmitter
    private(set) var spawnAccumulator: UInt64 = 0
    private(set) var tick: UInt64 = 0

    private let random: RandomSource
    private var arena: ParticleArena
    private var slice: EmitterArenaSlice
    private var metadata: Metadata
    private var birthCohorts: BirthCohorts
    private var spawnJobs: SpawnJobs?

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
        birthCohorts = BirthCohorts(
            capacity: compiled.storage.capacity,
            lifetimeTicks: compiled.constants.lifetimeTicks
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
        spawnJobs = nil
        guard self.compiled.storage != compiled.storage else {
            self.compiled = compiled
            reset()
            slice.storage.configure(
                velocityPacking: compiled.constants.velocityPacking,
                palette: ParticleColorPalette([compiled.constants.color])
            )
            return .reusedArena
        }

        self.compiled = compiled
        metadata = Metadata(
            capacity: compiled.storage.capacity,
            count: 0
        )
        birthCohorts = BirthCohorts(
            capacity: compiled.storage.capacity,
            lifetimeTicks: compiled.constants.lifetimeTicks
        )
        arena = Self.makeArena(compiled: compiled)
        slice = arena.slice(layout: compiled.storage)
        spawnAccumulator = 0
        tick = 0
        return .rebuiltArena
    }

    func advance(by delta: Float, executor: (any SimulationExecutor)? = nil) {
        if let executor {
            advanceParallel(by: delta, executor: executor)
            return
        }
        var spawnCount = scheduledSpawnCount()
        slice.storage.advance(by: delta)

        while let slot = birthCohorts.popExpired(at: UInt32(truncatingIfNeeded: tick)) {
            let index = metadata.indexForKnownLiveSlot(slot)
            if spawnCount > 0 {
                recycle(slot: slot, at: index, advancedBy: delta)
                spawnCount -= 1
            } else {
                remove(slot: slot, at: index)
            }
        }

        while spawnCount > 0 {
            appendSpawn(advancedBy: delta)
            spawnCount -= 1
        }
        tick &+= 1
    }

    private func advanceParallel(by delta: Float, executor: any SimulationExecutor) {
        var spawnCount = scheduledSpawnCount()
        slice.storage.advance(by: delta, executor: executor)
        if spawnJobs == nil {
            spawnJobs = SpawnJobs(capacity: Int(compiled.constants.spawnRate.whole)
                + (compiled.constants.spawnRate.remainder > 0 ? 1 : 0))
        }
        let jobs = spawnJobs!
        var count = 0
        // Reserve IDs and preserve birth-cohort order on the owning thread.
        while spawnCount > 0, let slot = birthCohorts.popExpired(at: UInt32(truncatingIfNeeded: tick)) {
            let index = metadata.indexForKnownLiveSlot(slot)
            jobs.requests[count] = .init(index: index, slot: slot,
                                        id: metadata.recycle(slot, at: index))
            scheduleDeath(for: slot)
            count += 1
            spawnCount -= 1
        }
        generate(count: count, jobs: jobs, delta: delta, executor: executor)
        for i in 0..<count {
            let request = jobs.requests[i]
            if compiled.storage.velocities == nil {
                slice.storage.replaceStationary(at: request.index, with: jobs.particles[i], slot: request.slot)
            } else {
                slice.storage.replaceMoving(at: request.index, with: jobs.particles[i], slot: request.slot)
            }
        }
        // Finish replacements before compaction can move their storage.
        while let slot = birthCohorts.popExpired(at: UInt32(truncatingIfNeeded: tick)) {
            remove(slot: slot, at: metadata.indexForKnownLiveSlot(slot))
        }
        for i in 0..<spawnCount {
            let index = slice.storage.count + i
            let allocated = metadata.allocateAvailable(at: index)
            jobs.requests[i] = .init(index: index, slot: allocated.slot, id: allocated.id)
            scheduleDeath(for: allocated.slot)
        }
        generate(count: spawnCount, jobs: jobs, delta: delta, executor: executor)
        for i in 0..<spawnCount {
            if compiled.storage.velocities == nil {
                slice.storage.appendStationary(jobs.particles[i], slot: jobs.requests[i].slot)
            } else {
                slice.storage.appendMoving(jobs.particles[i], slot: jobs.requests[i].slot)
            }
        }
        tick &+= 1
    }

    private func generate(count: Int, jobs: SpawnJobs, delta: Float,
                          executor: any SimulationExecutor) {
        guard count > 0 else { return }
        var context = SpawnJob(requests: jobs.requests, particles: jobs.particles,
                               random: random, constants: compiled.constants, delta: delta)
        withUnsafePointer(to: &context) { pointer in
            executor.execute(SimulationJob(count: count, context: pointer) { pointer, range in
                let job = pointer.assumingMemoryBound(to: SpawnJob.self).pointee
                for i in range {
                    var particle = Self.spawn(id: job.requests[i].id, random: job.random,
                                              constants: job.constants)
                    if job.constants.velocity.requiresStorage {
                        particle.position += particle.velocity * job.delta
                    }
                    job.particles[i] = particle
                }
            })
        }
    }

    func reset() {
        metadata.reset(count: 0)
        birthCohorts.reset()
        slice.storage.removeAll()
        spawnAccumulator = 0
        tick = 0
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
        birthCohorts.remove(removed.slot)
        remove(slot: removed.slot, at: removed.index)
        return true
    }

    @inline(__always)
    func remove(at index: Int) {
        let slot = slice.storage.slot(at: index)
        birthCohorts.remove(slot)
        remove(slot: slot, at: index)
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
        slice.layout.byteCount + metadata.byteCount + birthCohorts.byteCount
            + slice.storage.paletteByteCount
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
    private func recycle(
        slot: UInt32,
        at index: Int,
        advancedBy delta: Float
    ) {
        let id = metadata.recycle(slot, at: index)
        var particle = Self.spawn(
            id: id,
            random: random,
            constants: compiled.constants
        )
        if compiled.storage.velocities == nil {
            slice.storage.replaceStationary(
                at: index,
                with: particle,
                slot: slot
            )
        } else {
            particle.position += particle.velocity * delta
            slice.storage.replaceMoving(
                at: index,
                with: particle,
                slot: slot
            )
        }
        scheduleDeath(for: slot)
    }

    @inline(__always)
    private func appendSpawn(advancedBy delta: Float) {
        let allocated = metadata.allocateAvailable(at: slice.storage.count)
        var particle = Self.spawn(
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
            particle.position += particle.velocity * delta
            slice.storage.appendMoving(
                particle,
                slot: allocated.slot
            )
        }
        scheduleDeath(for: allocated.slot)
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
                slot: allocated.slot
            )
        } else {
            slice.storage.appendMoving(
                particle,
                slot: allocated.slot
            )
        }
        scheduleDeath(for: allocated.slot)
    }

    @inline(__always)
    private func scheduleDeath(for slot: UInt32) {
        birthCohorts.schedule(
            slot,
            deathTick: UInt32(truncatingIfNeeded: tick) &+ compiled.constants.lifetimeTicks
        )
    }

    private static func makeArena(compiled: CompiledEmitter) -> ParticleArena {
        ParticleArena(
            layout: compiled.storage,
            velocityPacking: compiled.constants.velocityPacking,
            palette: ParticleColorPalette([compiled.constants.color])
        )
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
            velocity = Vec3(
                RandomSource.float(from: block.x0, in: range),
                RandomSource.float(from: block.x1, in: range),
                RandomSource.float(from: block.x2, in: range)
            )
        }

        return Particle(
            id: id,
            position: constants.spawnRegion.sample(using: random, at: id),
            velocity: constants.velocityPacking.unpack(constants.velocityPacking.pack(velocity)),
            color: constants.color
        )
    }

}
