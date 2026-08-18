import Testing
@testable import PixlParticles

@Suite("System determinism")
struct SystemDeterminismTests {
    @Test("Legacy and emitter initializers produce identical simulation")
    func emitterInitializer() {
        let region = SpawnRegion.cube(size: [200, 200, 200])
        let legacy = System(
            seed: 42,
            particleCount: 101,
            spawnRegion: region,
            color: .init(red: 2, green: 0.5, blue: 0.25),
            duration: .seconds(2)
        )
        let authored = System(
            seed: 42,
            emitter: Emitter(
                capacity: 101,
                position: region,
                velocity: .random(-20 ..< 20),
                color: .init(red: 2, green: 0.5, blue: 0.25)
            ),
            duration: .seconds(2)
        )

        expectEqualParticles(legacy.particleSnapshot, authored.particleSnapshot)

        legacy.seek(to: .milliseconds(1_500))
        authored.seek(to: .milliseconds(1_500))

        expectEqualParticles(legacy.particleSnapshot, authored.particleSnapshot)
    }

    @Test("Stationary emitters remain fixed")
    func stationaryEmitter() {
        let system = System(
            seed: 42,
            emitter: Emitter(
                capacity: 101,
                position: .sphere(radius: 100),
                velocity: .stationary
            ),
            duration: .seconds(2)
        )
        let initial = system.particleSnapshot

        system.seek(to: .milliseconds(1_500))

        expectEqualParticles(system.particleSnapshot, initial)
        #expect(system.particleSnapshot.allSatisfy { $0.velocity == .zero })
    }

    private func expectEqualParticles(_ lhs: [Particle], _ rhs: [Particle]) {
        #expect(lhs.map(\.id) == rhs.map(\.id))
        #expect(lhs.map(\.previousPosition) == rhs.map(\.previousPosition))
        #expect(lhs.map(\.position) == rhs.map(\.position))
        #expect(lhs.map(\.velocity) == rhs.map(\.velocity))
        #expect(lhs.map(\.color) == rhs.map(\.color))
    }

    @Test("A seed reproduces spawned particles")
    func seededSpawn() {
        let first = System(
            seed: 42,
            particleCount: 101,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(2)
        ).particleSnapshot
        let second = System(
            seed: 42,
            particleCount: 101,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(2)
        ).particleSnapshot
        let different = System(
            seed: 43,
            particleCount: 101,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(first.count == 101)
        #expect(first.first?.id == 0)
        #expect(first.last?.id == 100)
        #expect(first.map(\.position) == second.map(\.position))
        #expect(first.map(\.velocity) == second.map(\.velocity))
        #expect(first.map(\.position) != different.map(\.position))
        #expect(first.map(\.velocity) != different.map(\.velocity))
    }

    @Test("Seeking backward resets and deterministically replays")
    func seek() {
        let instant = ContinuousClock.now
        let system = System(
            seed: 42,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(2)
        )

        system.seek(to: .milliseconds(1_500))
        let first = system.sample(at: instant, isPaused: true)
        let firstParticles = system.particleSnapshot

        system.seek(to: .milliseconds(500))
        system.seek(to: .milliseconds(1_500))
        let replayed = system.sample(at: instant, isPaused: true)
        let replayedParticles = system.particleSnapshot

        #expect(first.tick == 45)
        #expect(replayed.tick == 45)
        #expect(firstParticles.map(\.position) == replayedParticles.map(\.position))
        #expect(firstParticles.map(\.velocity) == replayedParticles.map(\.velocity))
        #expect(
            replayedParticles.map { $0.interpolated(by: replayed.interpolation) } ==
                replayedParticles.map(\.position)
        )

        system.seek(to: .milliseconds(1_500))
        let resumedAt = ContinuousClock.now
        _ = system.sample(at: resumedAt)
        let resumed = system.sample(
            at: resumedAt.advanced(by: .milliseconds(34))
        )

        #expect(resumed.tick == 46)
    }

    @Test("Seeking without stored rewind state regenerates deterministically")
    func seekWithoutStoredState() {
        let system = System(
            seed: 42,
            particleCount: 101,
            spawnRegion: .sphere(radius: 100),
            duration: .seconds(2),
            storesRewindState: false
        )

        system.seek(to: .milliseconds(1_500))
        let first = system.particleSnapshot
        system.seek(to: .milliseconds(500))
        system.seek(to: .milliseconds(1_500))

        let replayed = system.particleSnapshot
        #expect(replayed.map(\.id) == first.map(\.id))
        #expect(replayed.map(\.position) == first.map(\.position))
        #expect(replayed.map(\.velocity) == first.map(\.velocity))
    }

    @Test("Stops at its duration")
    func duration() {
        let system = System(
            seed: 0,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .milliseconds(100)
        )
        let start = ContinuousClock.now

        _ = system.sample(at: start)
        let completed = system.sample(
            at: start.advanced(by: .milliseconds(200))
        )
        let completedParticles = system.particleSnapshot
        let later = system.sample(
            at: start.advanced(by: .seconds(1))
        )
        let laterParticles = system.particleSnapshot

        #expect(completed.tick == 3)
        #expect(completed.time == .milliseconds(100))
        #expect(completed.interpolation == 1)
        #expect(later.tick == completed.tick)
        #expect(laterParticles.map(\.position) == completedParticles.map(\.position))
    }

    @Test("A zero duration runs forever")
    func infiniteDuration() {
        let system = System(
            seed: 0,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .zero
        )

        system.seek(to: .seconds(2))
        let sample = system.sample(at: .now, isPaused: true)

        #expect(sample.tick == 60)
        #expect(sample.time == .seconds(2))
        #expect(sample.interpolation == 0)
    }

    @Test("Extending duration preserves current state")
    func extendingDuration() {
        let system = System(
            seed: 0,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(1)
        )
        system.seek(to: .milliseconds(500))
        let particles = system.particleSnapshot

        system.setDuration(.seconds(2))

        #expect(system.duration == .seconds(2))
        #expect(system.particleSnapshot.map(\.position) == particles.map(\.position))
    }

    @Test("Shortening duration clamps state to the new end")
    func shorteningDuration() {
        let system = System(
            seed: 0,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .seconds(2)
        )
        let expected = System(
            seed: 0,
            particleCount: 16,
            spawnRegion: .cube(size: [200, 200, 200]),
            duration: .milliseconds(500)
        )
        system.seek(to: .seconds(1))
        expected.seek(to: .milliseconds(500))

        system.setDuration(.milliseconds(500))
        let sample = system.sample(at: .now, isPaused: true)

        #expect(sample.time == .milliseconds(500))
        #expect(system.particleSnapshot.map(\.position) == expected.particleSnapshot.map(\.position))
    }
}
