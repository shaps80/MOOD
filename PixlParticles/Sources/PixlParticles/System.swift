import Swift

public final class System {
    public let duration: Duration

    private let random: RandomSource
    private var loop = Loop(settings: .default)
    private var particles: [Particle] = []
    private var initialParticles: [Particle] = []
    private var tick: UInt64 = 0
    private var nextID: Particle.ID = 0
    private var initialNextID: Particle.ID = 0

    public init(
        seed: UInt64 = 0,
        duration: Duration = .seconds(2)
    ) {
        precondition(duration >= .zero)

        self.duration = duration
        random = RandomSource(seed: seed)

        particles = (0...100).map { _ in spawn() }
        initialParticles = particles
        initialNextID = nextID
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

    public func seek(to time: Duration) {
        precondition(time >= .zero && time <= duration)

        let targetTick = UInt64(
            (Self.seconds(time) / loop.fixedDeltaSeconds).rounded()
        )

        if targetTick < tick {
            particles = initialParticles
            tick = 0
            nextID = initialNextID
        }

        let delta = Float(loop.fixedDeltaSeconds)

        for _ in tick..<targetTick {
            update(by: delta)
        }

        for index in particles.indices {
            particles[index].resetInterpolation()
        }

        loop.rebase(to: tick)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }

    private func update(by delta: Float) {
        for index in particles.indices {
            particles[index].advance(by: delta)
        }

        tick += 1
    }

    private func spawn() -> Particle {
        defer { nextID += 1 }

        let positionBlock = random.block(
            at: nextID,
            channel: .position
        )
        let velocityBlock = random.block(
            at: nextID,
            channel: .velocity
        )
        let positionRange: Range<Float> = -100..<100
        let velocityRange: Range<Float> = -20..<20

        return Particle(
            id: nextID,
            position: [
                RandomSource.float(from: positionBlock.x0, in: positionRange),
                RandomSource.float(from: positionBlock.x1, in: positionRange),
                RandomSource.float(from: positionBlock.x2, in: positionRange),
            ],
            velocity: [
                RandomSource.float(from: velocityBlock.x0, in: velocityRange),
                RandomSource.float(from: velocityBlock.x1, in: velocityRange),
                RandomSource.float(from: velocityBlock.x2, in: velocityRange),
            ]
        )
    }
}

private extension RandomSource.Channel {
    static let position = Self(rawValue: 0)
    static let velocity = Self(rawValue: 1)
}
