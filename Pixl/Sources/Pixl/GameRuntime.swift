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

    private var game: G
    private var loop: Loop

    init(platform: any Platform) throws {
        game = try G(platform: platform)
        loop = Loop(settings: G.loopSettings)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        let schedule = loop.advance(to: .now)

        var index: UInt32 = 0
        while index < schedule.fixedUpdateCount {
            let tickIndex = schedule.firstTickIndex &+ UInt64(index)
            game.fixedUpdate(
                FixedTime(
                    tickIndex: tickIndex,
                    deltaSeconds: schedule.fixedDeltaSeconds,
                    elapsedSeconds: Double(tickIndex)
                        * schedule.fixedDeltaSeconds
                )
            )
            index &+= 1
        }

        game.update(schedule.updateTime)

        try game.render(
            on: platform,
            output: output,
            frame: frame,
            time: schedule.renderTime
        )
    }
}
