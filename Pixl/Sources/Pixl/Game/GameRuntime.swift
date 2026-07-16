import Swift

final class GameRuntime<G: Game>: PlatformGame {
    static var gameSettings: GameSettings {
        G.gameSettings
    }

    static var renderSettings: RenderSettings {
        G.renderSettings
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
    private let lanes: Lanes
    private var latestMetrics: PerformanceMetrics = .zero
    private var metricsCollector: PerformanceMetricsCollector

    init(platform: any Platform) throws {
        context = .init(platform: platform, renderSettings: G.renderSettings)
        game = try G(context: context)
        loop = Loop(settings: G.loopSettings)
        lanes = .init()
        metricsCollector = .init(
            preferredFramesPerSecond: G.gameSettings.preferredFps
        )
    }

    init(game: G, executionSettings: ExecutionSettings) {
        self.game = game
        context = .testing
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
            cpuRenderSeconds: Self.seconds(renderEnd - gameEnd),
            drawCount: frame.drawCount
        )
    }

    func runLifecycle(_ schedule: LoopSchedule) {
        var index: UInt32 = 0
        while index < schedule.fixedUpdateCount {
            let tickIndex = schedule.firstTickIndex &+ UInt64(index)
            let time = FixedTime(
                tickIndex: tickIndex,
                deltaSeconds: schedule.fixedDeltaSeconds,
                elapsedSeconds: Double(tickIndex)
                    * schedule.fixedDeltaSeconds
            )
            game.fixedUpdate(time,
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
