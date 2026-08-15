import Swift

public final class System {
    public let duration: Duration

    private let random: RandomSource
    private let spawnRegion: SpawnRegion
    private var loop: Loop
    private let durationInTicks: UInt64
    private var particles: [Particle] = []
    private var initialParticles: [Particle] = []
    private var tick: UInt64 = 0
    private var nextID: Particle.ID = 0
    private var initialNextID: Particle.ID = 0

    public init(
        seed: UInt64 = 0,
        particleCount: Int = 0,
        spawnRegion: SpawnRegion = .box(size: [200, 200, 200]),
        duration: Duration = .seconds(2)
    ) {
        precondition(particleCount >= 0)
        precondition(duration >= .zero)
        spawnRegion.validate()

        let loop = Loop(settings: .default)
        let durationInTicks = (
            Loop.seconds(duration) / loop.fixedDeltaSeconds
        ).rounded()
        precondition(durationInTicks <= Double(UInt64.max))

        self.duration = duration
        self.durationInTicks = UInt64(durationInTicks)
        random = RandomSource(seed: seed)
        self.spawnRegion = spawnRegion
        self.loop = loop

        particles = (0..<particleCount).map { _ in spawn() }
        initialParticles = particles
        initialNextID = nextID
    }

    public func sample(
        at instant: ContinuousClock.Instant,
        isPaused: Bool = false
    ) -> Sample {
        let isComplete = tick >= durationInTicks
        let schedule = loop.advance(
            to: instant,
            timeScale: isPaused || isComplete ? 0 : 1
        )

        let delta = Float(schedule.fixedDeltaSeconds)
        let remainingUpdates = durationInTicks - min(tick, durationInTicks)
        let updateCount = min(
            UInt64(schedule.fixedUpdateCount),
            remainingUpdates
        )

        for _ in 0..<updateCount {
            update(by: delta)
        }

        let isNowComplete = tick >= durationInTicks
        let interpolation = isNowComplete
            ? 1
            : Float(schedule.renderTime.interpolation)
        let time = isNowComplete
            ? duration
            : Duration.seconds(Double(tick) * schedule.fixedDeltaSeconds)

        return .init(
            particles: particles,
            interpolation: interpolation,
            tick: tick,
            time: time
        )
    }

    public func seek(to time: Duration) {
        precondition(time >= .zero && time <= duration)

        let targetTick = UInt64(
            (Loop.seconds(time) / loop.fixedDeltaSeconds).rounded()
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

    private func update(by delta: Float) {
        for index in particles.indices {
            particles[index].advance(by: delta)
        }

        tick += 1
    }

    private func spawn() -> Particle {
        defer { nextID += 1 }

        let velocityBlock = random.block(
            at: nextID,
            channel: .velocity
        )
        let velocityRange: Range<Float> = -20..<20

        return Particle(
            id: nextID,
            position: spawnRegion.sample(using: random, at: nextID),
            velocity: [
                RandomSource.float(from: velocityBlock.x0, in: velocityRange),
                RandomSource.float(from: velocityBlock.x1, in: velocityRange),
                RandomSource.float(from: velocityBlock.x2, in: velocityRange),
            ]
        )
    }
}
