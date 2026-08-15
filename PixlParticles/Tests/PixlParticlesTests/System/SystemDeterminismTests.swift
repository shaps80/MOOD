import Testing
@testable import PixlParticles

@Suite("System determinism")
struct SystemDeterminismTests {
    @Test("A seed reproduces spawned particles")
    func seededSpawn() {
        let instant = ContinuousClock.now
        let first = System(seed: 42).sample(at: instant).particles
        let second = System(seed: 42).sample(at: instant).particles
        let different = System(seed: 43).sample(at: instant).particles

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
        let system = System(seed: 42)

        system.seek(to: 45)
        let first = system.sample(at: instant, isPaused: true)

        system.seek(to: 15)
        system.seek(to: 45)
        let replayed = system.sample(at: instant, isPaused: true)

        #expect(first.tick == 45)
        #expect(replayed.tick == 45)
        #expect(first.particles.map(\.position) == replayed.particles.map(\.position))
        #expect(first.particles.map(\.velocity) == replayed.particles.map(\.velocity))
        #expect(
            replayed.particles.map { $0.interpolated(by: replayed.interpolation) } ==
                replayed.particles.map(\.position)
        )
    }
}
