import PixlPlatform

final class GameRuntime<G: Game>: PlatformGame {
    static var gameSettings: GameSettings {
        G.gameSettings
    }

    static var renderSettings: RenderSettings {
        G.renderSettings
    }

    static var audioSettings: AudioSettings {
        G.audioSettings
    }

    static var assetPath: String? {
        G.assetSettings.path
    }

    static var assetSourcePath: String? {
        G.assetSettings.sourcePath
    }

    private var game: G
    private let context: GameContext
    private var loop: Loop
    private var latestMetrics: PerformanceMetrics = .zero
    private var metricsCollector: PerformanceMetricsCollector
    private var phase: GamePhase?

    init(platform: any Platform) throws {
        context = .init(
            platform: platform,
            format: G.renderSettings.drawableFormat,
            renderQueueSettings: G.renderQueueSettings
        )
        game = try G(context: context)
        loop = Loop(settings: G.loopSettings)
        metricsCollector = .init(
            preferredFramesPerSecond: G.gameSettings.preferredFps
        )
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        context.coordinateConverter = .init(
            presentationSize: output.texture.descriptor.size,
            displayScale: platform.displayScale
        )
        context.mouse.update(
            rawLocation: platform.mouse.rawLocation,
            rawTranslation: platform.mouse.rawTranslation
        )
        context.inputs.update()
        let frameStart = ContinuousClock.now
        let schedule = loop.advance(
            to: frameStart,
            timeScale: context.timeScale
        )
        context.presentationFrameIndex = schedule.renderTime.frameIndex
        let gameStart = ContinuousClock.now

        runLifecycle(schedule)
        let gameEnd = ContinuousClock.now

        try game.render(
            on: platform,
            output: output,
            frame: frame,
            time: RenderTime(
                frameIndex: schedule.renderTime.frameIndex,
                interpolation: schedule.renderTime.interpolation,
                metrics: latestMetrics
            ),
            context: context
        )
        let renderEnd = ContinuousClock.now
        latestMetrics = metricsCollector.record(
            frameIndex: schedule.renderTime.frameIndex,
            frameTimeSeconds: schedule.frameTimeSeconds,
            cpuGameSeconds: Self.seconds(gameEnd - gameStart),
            cpuRenderSeconds: Self.seconds(renderEnd - gameEnd),
            drawCount: frame.drawCount,
            renderQueue: context.consumeRenderMetrics()
        )
    }

    func didEnter(_ phase: GamePhase) {
        guard phase != self.phase else { return }
        self.phase = phase
        game.didEnter(phase, context: context)
    }

    func runLifecycle(_ schedule: LoopSchedule) {
        var index: UInt32 = 0
        while index < schedule.fixedUpdateCount {
            let tickIndex = schedule.firstTickIndex &+ UInt64(index)
            let time = FixedTime(
                tickIndex: tickIndex,
                delta: schedule.fixedDeltaSeconds,
                elapsedSeconds: Double(tickIndex)
                    * schedule.fixedDeltaSeconds
            )
            game.fixedUpdate(
                time,
                context: context
            )
            index &+= 1
        }

        game.update(
            schedule.updateTime,
            context: context
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}
