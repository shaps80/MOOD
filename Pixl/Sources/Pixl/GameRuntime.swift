import Swift

final class GameRuntime<G: Game>: PlatformGame {
    static var defaultShaders: Shader {
        G.defaultShaders
    }

    static var gameSettings: GameSettings {
        G.gameSettings
    }

    static var renderSettings: RenderSettings {
        G.renderSettings
    }

    private let game: G
    private var loop: Loop
    private let lanes: Lanes
    private var latestMetrics: PerformanceMetrics = .zero
    private var metricsCollector: PerformanceMetricsCollector

    init(platform: any Platform) throws {
        game = try G(platform: platform)
        loop = Loop(settings: G.loopSettings)
        lanes = .init()
        metricsCollector = .init(
            preferredFramesPerSecond: G.gameSettings.preferredFps
        )
    }

    init(game: G, executionSettings: ExecutionSettings) {
        self.game = game
        loop = Loop(settings: G.loopSettings)
        lanes = .init(settings: executionSettings)
        metricsCollector = .init(
            preferredFramesPerSecond: G.gameSettings.preferredFps
        )
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        let frameStart = ContinuousClock.now
        let schedule = loop.advance(to: frameStart)
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
            )
        )

        let renderEnd = ContinuousClock.now
        latestMetrics = metricsCollector.record(
            frameIndex: schedule.renderTime.frameIndex,
            frameTimeSeconds: schedule.frameTimeSeconds,
            cpuGameSeconds: Self.seconds(gameEnd - gameStart),
            cpuRenderSeconds: Self.seconds(renderEnd - gameEnd)
        )
    }

    func runLifecycle(_ schedule: LoopSchedule) {
        var index: UInt32 = 0
        while index < schedule.fixedUpdateCount {
            let tickIndex = schedule.firstTickIndex &+ UInt64(index)
            game.fixedUpdate(
                FixedTime(
                    tickIndex: tickIndex,
                    deltaSeconds: schedule.fixedDeltaSeconds,
                    elapsedSeconds: Double(tickIndex)
                        * schedule.fixedDeltaSeconds
                ),
                lanes: lanes
            )
            index &+= 1
        }

        game.update(schedule.updateTime, lanes: lanes)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}
