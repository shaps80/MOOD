import Swift

struct LoopSchedule {
    let fixedUpdateCount: UInt32
    let firstTickIndex: UInt64
    let fixedDeltaSeconds: Double
    let frameTimeSeconds: Double
    let updateTime: UpdateTime
    let renderTime: RenderTime
}

struct Loop {
    private let settings: LoopSettings
    private var previousInstant: ContinuousClock.Instant?
    private var accumulator = 0.0
    private var elapsedSeconds = 0.0
    private var frameIndex: UInt64 = 0
    private var tickIndex: UInt64 = 0

    init(settings: LoopSettings) {
        self.settings = settings
    }

    mutating func advance(
        to now: ContinuousClock.Instant,
        timeScale: Double = 1
    ) -> LoopSchedule {
        precondition(timeScale.isFinite && timeScale >= 0)

        guard let previousInstant else {
            self.previousInstant = now
            return schedule(
                fixedUpdateCount: 0,
                firstTickIndex: tickIndex,
                fixedDeltaSeconds: fixedDeltaSeconds,
                frameTimeSeconds: 0,
                deltaSeconds: 0,
                interpolation: settings.fixedStep == nil ? 1 : 0
            )
        }

        self.previousInstant = now
        frameIndex &+= 1

        let rawDelta = max(0, Self.seconds(now - previousInstant))
        let delta = min(rawDelta, settings.maximumDeltaSeconds) * timeScale
        elapsedSeconds += delta

        guard let fixedStep = settings.fixedStep else {
            return schedule(
                fixedUpdateCount: 0,
                firstTickIndex: tickIndex,
                fixedDeltaSeconds: 0,
                frameTimeSeconds: rawDelta,
                deltaSeconds: delta,
                interpolation: 1
            )
        }

        let step = 1.0 / Double(fixedStep.updatesPerSecond)
        let maximumAccumulated = step * Double(
            fixedStep.maximumUpdatesPerFrame
        )
        accumulator = min(accumulator + delta, maximumAccumulated)

        let updateCount = min(
            UInt32(accumulator / step),
            fixedStep.maximumUpdatesPerFrame
        )
        accumulator = max(0, accumulator - Double(updateCount) * step)

        let firstTickIndex = tickIndex &+ 1
        tickIndex &+= UInt64(updateCount)

        return schedule(
            fixedUpdateCount: updateCount,
            firstTickIndex: firstTickIndex,
            fixedDeltaSeconds: step,
            frameTimeSeconds: rawDelta,
            deltaSeconds: delta,
            interpolation: min(1, accumulator / step)
        )
    }

    private var fixedDeltaSeconds: Double {
        guard let fixedStep = settings.fixedStep else { return 0 }
        return 1.0 / Double(fixedStep.updatesPerSecond)
    }

    private func schedule(
        fixedUpdateCount: UInt32,
        firstTickIndex: UInt64,
        fixedDeltaSeconds: Double,
        frameTimeSeconds: Double,
        deltaSeconds: Double,
        interpolation: Double
    ) -> LoopSchedule {
        LoopSchedule(
            fixedUpdateCount: fixedUpdateCount,
            firstTickIndex: firstTickIndex,
            fixedDeltaSeconds: fixedDeltaSeconds,
            frameTimeSeconds: frameTimeSeconds,
            updateTime: UpdateTime(
                frameIndex: frameIndex,
                deltaSeconds: deltaSeconds,
                elapsedSeconds: elapsedSeconds
            ),
            renderTime: RenderTime(
                frameIndex: frameIndex,
                interpolation: interpolation
            )
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}
