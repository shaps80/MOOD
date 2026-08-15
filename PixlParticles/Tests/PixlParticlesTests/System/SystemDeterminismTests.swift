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

        system.seek(to: .milliseconds(1_500))
        let first = system.sample(at: instant, isPaused: true)

        system.seek(to: .milliseconds(500))
        system.seek(to: .milliseconds(1_500))
        let replayed = system.sample(at: instant, isPaused: true)

        #expect(first.tick == 45)
        #expect(replayed.tick == 45)
        #expect(first.particles.map(\.position) == replayed.particles.map(\.position))
        #expect(first.particles.map(\.velocity) == replayed.particles.map(\.velocity))
        #expect(
            replayed.particles.map { $0.interpolated(by: replayed.interpolation) } ==
                replayed.particles.map(\.position)
        )

        system.seek(to: .milliseconds(1_500))
        let resumedAt = ContinuousClock.now
        _ = system.sample(at: resumedAt)
        let resumed = system.sample(
            at: resumedAt.advanced(by: .milliseconds(34))
        )

        #expect(resumed.tick == 46)
    }

    @Test("Stops at its duration")
    func duration() {
        let system = System(duration: .milliseconds(100))
        let start = ContinuousClock.now

        _ = system.sample(at: start)
        let completed = system.sample(
            at: start.advanced(by: .milliseconds(200))
        )
        let later = system.sample(
            at: start.advanced(by: .seconds(1))
        )

        #expect(completed.tick == 3)
        #expect(completed.time == .milliseconds(100))
        #expect(completed.interpolation == 1)
        #expect(later.tick == completed.tick)
        #expect(later.particles.map(\.position) == completed.particles.map(\.position))
    }
}
