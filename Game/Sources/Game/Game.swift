import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let state: State

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(width: 800, height: 400),
        )
    }

    static var assetSettings: AssetSettings {
        .init()
    }

    init(context: GameContext) throws {
        state = try .init(context: context)
    }

    func fixedUpdate(_ time: FixedTime, lanes: Lanes) {
        state.player.fixedUpdate(time, lanes: lanes)
    }

    func update(_ time: UpdateTime, lanes: Lanes) {
        state.player.update(time, lanes: lanes)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {
        _ = frame.clear(target: output)

        try state.player.render(
            on: platform,
            output: output,
            frame: frame,
            time: time
        )

        logMetrics(metrics: time.metrics)
    }

    private func logMetrics(metrics: PerformanceMetrics) {
        state.metricsElapsed += metrics.frameTimeSeconds
        guard state.metricsElapsed >= 5 else { return }
        state.metricsElapsed.formTruncatingRemainder(dividingBy: 5)
        print(metrics.summary)
    }
}

private extension Game {
    final class State: @unchecked Sendable {
        var metricsElapsed = 0.0
        var pipeline: RenderPipeline
        var player: Player

        init(context: GameContext) throws {
            pipeline = try context.platform.device.makeRenderPipeline(
                .init(
                    vertex: .vertex,
                    fragment: .fragment,
                    vertexLayout: .primitive,
                    colorFormat: context.renderSettings.drawableFormat
                )
            )
            player = try .init(pipeline: pipeline, context: context)
        }
    }
}
