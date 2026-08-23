@testable import PixlParticles
import Testing

struct EmitterInstanceTests {
    @Test("Constant edits preserve the emitter arena")
    func constantEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            spawnRegion: .sphere(radius: 10),
            color: .init([.set(.white)]),
            size: .init([.set([1, 2])]),
            rotation: .init([.set(0)])
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity

        emitter[\.color][0] = .set(.init(red: 4, green: 1, blue: 0.25))
        emitter[\.size][0] = .set([3, 6])
        emitter[\.rotation][0] = .set(0.5)

        #expect(instance.apply(compiler.compile(emitter)) == .reusedArena)
        #expect(instance.arenaIdentity == identity)
    }

    @Test("Storage-layout edits rebuild only the emitter arena")
    func structuralEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            spawnRegion: .point(.zero),
            velocity: .init()
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity
        let stationaryByteCount = instance.arenaByteCount

        emitter[\.velocity].append(
            .set(.random(from: [-1, -1, -1], to: [1, 1, 1], variation: .perValue))
        )

        #expect(instance.apply(compiler.compile(emitter)) == .rebuiltArena)
        #expect(instance.arenaIdentity != identity)
        #expect(instance.arenaByteCount > stationaryByteCount)
    }

    @Test("Renderer edits preserve particle storage")
    func rendererEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            spawnRegion: .point(.zero)
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity

        emitter.renderers = [.init(mode: .billboard)]

        #expect(instance.apply(compiler.compile(emitter)) == .reusedArena)
        #expect(instance.arenaIdentity == identity)
    }

    @Test("Removal keeps moving particles dense and repairs stable mapping")
    func movingRemoval() throws {
        var emitter = Emitter(
            capacity: 5,
            spawnRegion: .sphere(radius: 10)
        )
        emitter[\.velocity].append(
            .set(.random(from: [-1, -2, -3], to: [1, 2, 3]))
        )
        let instance = EmitterInstance(emitter: emitter)
        let initial = instance.particles()
        let removed = initial[1]
        let moved = initial[4]

        #expect(instance.remove(removed.id))

        let particles = instance.particles()
        #expect(instance.aliveCount == 4)
        #expect(particles.count == 4)
        #expect(signature(particles[1]) == signature(moved))
        #expect(instance.remove(removed.id) == false)
        #expect(instance.remove(moved.id))
        #expect(instance.aliveCount == 3)
    }

    @Test("Removal supports storage without velocity")
    func stationaryRemoval() {
        let emitter = Emitter(
            capacity: 5,
            spawnRegion: .line(from: .zero, to: [5, 5, 5])
        )
        let instance = EmitterInstance(emitter: emitter)
        let initial = instance.particles()

        #expect(instance.remove(initial[2].id))

        let particles = instance.particles()
        #expect(particles.count == 4)
        #expect(signature(particles[2]) == signature(initial[4]))
    }

    @Test("Spawning reuses released slots with a new generation")
    func reuse() throws {
        let emitter = Emitter(
            capacity: 5,
            spawnRegion: .sphere(radius: 10)
        )
        let first = EmitterInstance(emitter: emitter)
        let second = EmitterInstance(emitter: emitter)
        let removedID = first.particles()[1].id

        #expect(first.remove(removedID))
        #expect(second.remove(removedID))

        let firstID = try #require(first.spawn())
        let secondID = try #require(second.spawn())

        #expect(firstID == Particle.ID(1) << 32 | 1)
        #expect(firstID == secondID)
        #expect(first.particles().map(signature) == second.particles().map(signature))
        #expect(first.remove(removedID) == false)
        #expect(first.remove(firstID))
    }

    @Test("Reset restores exact initial order and state after reuse")
    func resetAfterReuse() throws {
        var emitter = Emitter(
            capacity: 5,
            spawnRegion: .sphere(radius: 10)
        )
        emitter[\.velocity].append(
            .set(.random(from: [-1, -2, -3], to: [1, 2, 3]))
        )
        let instance = EmitterInstance(emitter: emitter)
        let initial = instance.particles().map(signature)

        #expect(instance.remove(instance.particles()[1].id))
        _ = try #require(instance.spawn())
        #expect(instance.remove(instance.particles()[3].id))

        instance.reset()

        #expect(instance.aliveCount == 5)
        #expect(instance.particles().map(signature) == initial)
    }
}

private struct Signature: Equatable {
    let id: Particle.ID
    let previousPosition: Vec3
    let position: Vec3
    let velocity: Vec3
    let color: Color
}

private func signature(_ particle: Particle) -> Signature {
    Signature(
        id: particle.id,
        previousPosition: particle.previousPosition,
        position: particle.position,
        velocity: particle.velocity,
        color: particle.color
    )
}
