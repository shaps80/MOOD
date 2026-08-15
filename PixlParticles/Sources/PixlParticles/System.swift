import Swift

public final class System {
    private var loop = Loop(settings: .default)
    private var particles: [Particle]
    private var tick: UInt64 = 0

    public init() {
        particles = [
            .init(position: [0, 0, 0], velocity: [20, 0, 0]),
            .init(position: [5, 0, 0], velocity: [0, 20, 0]),
            .init(position: [-5, 0, 0], velocity: [-20, 0, 0]),
        ]
    }

    public func sample(
        at instant: ContinuousClock.Instant,
        isPaused: Bool = false
    ) -> Sample {
        let schedule = loop.advance(
            to: instant,
            timeScale: isPaused ? 0 : 1
        )
        
        let delta = Float(schedule.fixedDeltaSeconds)
        let interpolation = Float(schedule.renderTime.interpolation)

        for _ in 0..<schedule.fixedUpdateCount {
            for index in particles.indices {
                particles[index].advance(by: delta)
            }

            tick += 1
        }

        return .init(
            particles: particles,
            interpolation: interpolation,
            tick: tick
        )
    }
}
