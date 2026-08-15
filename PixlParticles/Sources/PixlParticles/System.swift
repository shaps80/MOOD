import Swift

public final class System {
    private let random: RandomSource
    private var loop = Loop(settings: .default)
    private var particles: [Particle] = []
    private var tick: UInt64 = 0
    private var nextID: Particle.ID = 0

    public init(seed: UInt64 = 0) {
        random = RandomSource(seed: seed)

        particles = [
            spawn(position: [0, 0, 0], velocity: [20, 0, 0]),
            spawn(position: [5, 0, 0], velocity: [0, 20, 0]),
            spawn(position: [-5, 0, 0], velocity: [-20, 0, 0]),
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
            update(by: delta)
        }

        return .init(
            particles: particles,
            interpolation: interpolation,
            tick: tick
        )
    }

    private func update(by delta: Float) {
        for index in particles.indices {
            particles[index].advance(by: delta)
        }

        tick += 1
    }

    private func spawn(position: Vec3, velocity: Vec3) -> Particle {
        defer { nextID += 1 }

        return Particle(
            id: nextID,
            position: position,
            velocity: velocity
        )
    }
}

private extension RandomSource.Channel {
    static let position = Self(rawValue: 0)
    static let velocity = Self(rawValue: 1)
}
