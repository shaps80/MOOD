import Testing
@testable import PixlParticles

@Suite("System determinism")
struct SystemDeterminismTests {
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
}
