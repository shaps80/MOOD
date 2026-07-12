import PixlConcurrency
import Swift

final class GameRuntime<G: Game>: PlatformGame {
    private final class State: @unchecked Sendable {
        let game: G

        init(_ game: G) {
            self.game = game
        }
    }

    private final class LifecycleContext: @unchecked Sendable {
        enum Phase: Sendable {
            case fixedUpdate(FixedTime)
            case update(UpdateTime)
        }

        let state: State
        let phase: Phase

        init(state: State, phase: Phase) {
            self.state = state
            self.phase = phase
        }
    }

    private enum LifecycleProgram: LaneProgram {
        static func execute(_ context: LifecycleContext, on lane: Lane) {
            switch context.phase {
            case .fixedUpdate(let time):
                context.state.game.fixedUpdate(time, lane: lane)
            case .update(let time):
                context.state.game.update(time, lane: lane)
            }
        }
    }

    static var defaultShaders: Shader {
        G.defaultShaders
    }

    static var gameSettings: GameSettings {
        G.gameSettings
    }

    static var renderSettings: RenderSettings {
        G.renderSettings
    }

    private let state: State
    private var loop: Loop
    private let executionGroup: ExecutionGroup<LifecycleProgram>
    private var latestMetrics: PerformanceMetrics = .zero
    private var metricsCollector: PerformanceMetricsCollector

    init(platform: any Platform) throws {
        state = State(try G(platform: platform))
        loop = Loop(settings: G.loopSettings)
        executionGroup = .init()
        metricsCollector = .init(
            preferredFramesPerSecond: G.gameSettings.preferredFps
        )
    }

    init(game: G, executionSettings: ExecutionSettings) {
        state = State(game)
        loop = Loop(settings: G.loopSettings)
        executionGroup = .init(settings: executionSettings)
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

        try state.game.render(
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
            executionGroup.run(
                LifecycleContext(
                    state: state,
                    phase: .fixedUpdate(
                        FixedTime(
                            tickIndex: tickIndex,
                            deltaSeconds: schedule.fixedDeltaSeconds,
                            elapsedSeconds: Double(tickIndex)
                                * schedule.fixedDeltaSeconds
                        )
                    )
                )
            )
            index &+= 1
        }

        executionGroup.run(
            LifecycleContext(state: state, phase: .update(schedule.updateTime))
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}
