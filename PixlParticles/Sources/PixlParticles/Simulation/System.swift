import PixlRenderer
import Swift

public final class System {
    public private(set) var duration: Duration

    var particleSnapshot: [Particle] { storage.particles() }

    package var particleCount: Int { storage.count }

    private let random: RandomSource
    private let spawnRegion: SpawnRegion
    private let color: Color
    private var loop: Loop
    private var durationInTicks: UInt64
    private var storage: ParticleStorage
    private let initialState: InitialParticleState?
    private var tick: UInt64 = 0
    private var nextID: Particle.ID = 0
    private var initialNextID: Particle.ID = 0

    public init(
        seed: UInt64,
        particleCount: Int,
        spawnRegion: SpawnRegion,
        color: Color = .white,
        duration: Duration,
        storesRewindState: Bool = true
    ) {
        precondition(particleCount >= 0)
        precondition(duration >= .zero)
        spawnRegion.validate()

        let loop = Loop(settings: .default)
        let durationInTicks = Self.ticks(for: duration, using: loop)

        let randomSource = RandomSource(seed: seed)
        let region = spawnRegion

        self.duration = duration
        self.durationInTicks = durationInTicks
        random = randomSource
        self.spawnRegion = region
        self.color = color
        self.loop = loop

        storage = ParticleStorage(count: particleCount) { index in
            Self.spawn(
                id: Particle.ID(index),
                random: randomSource,
                region: region,
                color: color
            )
        }
        initialState = storesRewindState ? storage.initialState() : nil
        nextID = Particle.ID(particleCount)
        initialNextID = nextID
    }

    public func setDuration(_ duration: Duration) {
        precondition(duration >= .zero)

        let durationInTicks = Self.ticks(for: duration, using: loop)
        self.duration = duration
        self.durationInTicks = durationInTicks

        if tick > durationInTicks {
            seek(to: duration)
        }
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
            interpolation: interpolation,
            tick: tick,
            time: time
        )
    }

    public func seek(to time: Duration) {
        precondition(
            time >= .zero && (duration == .zero || time <= duration)
        )

        let targetTick = UInt64(
            (Loop.seconds(time) / loop.fixedDeltaSeconds).rounded()
        )

        if targetTick < tick {
            if let initialState {
                storage.restore(from: initialState)
            } else {
                storage = ParticleStorage(count: storage.count) { index in
                    Self.spawn(
                        id: Particle.ID(index),
                        random: random,
                        region: spawnRegion,
                        color: color
                    )
                }
            }
            tick = 0
            nextID = initialNextID
        }

        let delta = Float(loop.fixedDeltaSeconds)

        for _ in tick..<targetTick {
            update(by: delta)
        }

        storage.resetInterpolation()
        loop.rebase(to: tick)
    }

    func update(by delta: Float) {
        storage.advance(by: delta)

        tick += 1
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try storage.withRenderingData(body)
    }

    private static func spawn(
        id: Particle.ID,
        random: RandomSource,
        region: SpawnRegion,
        color: Color
    ) -> Particle {
        let velocityBlock = random.block(
            at: id,
            channel: .velocity
        )
        let velocityRange: Range<Float> = -20..<20

        return Particle(
            id: id,
            position: region.sample(using: random, at: id),
            velocity: [
                RandomSource.float(from: velocityBlock.x0, in: velocityRange),
                RandomSource.float(from: velocityBlock.x1, in: velocityRange),
                RandomSource.float(from: velocityBlock.x2, in: velocityRange),
            ],
            color: color
        )
    }

    private static func ticks(for duration: Duration, using loop: Loop) -> UInt64 {
        guard duration > .zero else { return .max }

        let ticks = (
            Loop.seconds(duration) / loop.fixedDeltaSeconds
        ).rounded()
        precondition(ticks <= Double(UInt64.max))
        return UInt64(ticks)
    }
}
