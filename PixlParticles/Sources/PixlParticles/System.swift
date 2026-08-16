import PixlRenderer
import Swift

public final class System {
    public let duration: Duration

    var particleSnapshot: [Particle] { storage.particles() }

    package var particleCount: Int { storage.count }

    private let random: RandomSource
    private let spawnRegion: SpawnRegion
    private var loop: Loop
    private let durationInTicks: UInt64
    private var storage: ParticleStorage
    private let initialState: InitialParticleState
    private var tick: UInt64 = 0
    private var nextID: Particle.ID = 0
    private var initialNextID: Particle.ID = 0

    public init(
        seed: UInt64,
        particleCount: Int,
        spawnRegion: SpawnRegion,
        duration: Duration
    ) {
        precondition(particleCount >= 0)
        precondition(duration >= .zero)
        spawnRegion.validate()

        let loop = Loop(settings: .default)
        let durationInTicks = (
            Loop.seconds(duration) / loop.fixedDeltaSeconds
        ).rounded()
        precondition(durationInTicks <= Double(UInt64.max))

        let randomSource = RandomSource(seed: seed)
        let region = spawnRegion

        self.duration = duration
        self.durationInTicks = UInt64(durationInTicks)
        random = randomSource
        self.spawnRegion = region
        self.loop = loop

        storage = ParticleStorage(count: particleCount) { index in
            Self.spawn(
                id: Particle.ID(index),
                random: randomSource,
                region: region
            )
        }
        initialState = storage.initialState()
        nextID = Particle.ID(particleCount)
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
            storage.restore(from: initialState)
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

    package func withRenderingData<Result: ~Copyable>(
        _ body: (
            Span<Vector3Batch>,
            Span<Vector3Batch>,
            Span<SIMD4<UInt64>>,
            Int
        ) throws -> Result
    ) rethrows -> Result {
        try storage.withRenderingData(body)
    }

    private static func spawn(
        id: Particle.ID,
        random: RandomSource,
        region: SpawnRegion
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
            ]
        )
    }
}
