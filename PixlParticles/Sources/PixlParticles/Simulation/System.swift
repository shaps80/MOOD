import PixlRenderer
import Swift

public final class System {
    public private(set) var duration: Duration

    var particleSnapshot: [Particle] { emitter.particles() }

    package var particleCount: Int { emitter.aliveCount }

    private var emitter: EmitterInstance
    private var loop: Loop
    private var durationInTicks: UInt64
    private var tick: UInt64 = 0

    public convenience init(
        seed: UInt64,
        particleCount: Int,
        spawnRegion: SpawnRegion,
        color: Color = .white,
        duration: Duration,
        storesRewindState: Bool = true
    ) {
        self.init(
            seed: seed,
            emitter: Emitter(
                capacity: particleCount,
                spawnRegion: spawnRegion,
                color: .init([.set(color)])
            ),
            duration: duration,
            storesRewindState: storesRewindState
        )
    }

    public init(
        seed: UInt64,
        emitter: Emitter,
        duration: Duration,
        storesRewindState: Bool = true
    ) {
        precondition(duration >= .zero)

        let loop = Loop(settings: .default)
        let durationInTicks = Self.ticks(for: duration, using: loop)

        self.duration = duration
        self.durationInTicks = durationInTicks
        self.loop = loop
        self.emitter = EmitterInstance(
            compiled: EmitterCompiler().compile(emitter),
            random: RandomSource(seed: seed),
            storesRewindState: storesRewindState
        )
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
            emitter.reset()
            tick = 0
        }

        let delta = Float(loop.fixedDeltaSeconds)

        for _ in tick..<targetTick {
            update(by: delta)
        }

        emitter.resetInterpolation()
        loop.rebase(to: tick)
    }

    func update(by delta: Float) {
        emitter.advance(by: delta)

        tick += 1
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try emitter.withRenderingData(body)
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
