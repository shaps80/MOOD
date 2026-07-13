import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let state = State()

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(width: 800, height: 400)
        )
    }

    init(context: GameContext) throws {
        let world = context.register(World())
        let players = world.register(Player.self, capacity: 1_000)
        for _ in 0..<1000 {
            _ = try players.spawn()
        }
    }

    func render(on platform: any Platform, output: RenderTarget, frame: borrowing Frame, time: RenderTime) throws {
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
        var rotation: Double = 0
        var previousRotation: Double = 0
        var metricsElapsed = 0.0
    }
}
