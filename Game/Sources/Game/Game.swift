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

    static let assetSettings: AssetSettings = .init()

    init(context: GameContext) throws {
        self.state = try .init(context: context)
    }

    func didEnter(_ phase: GamePhase, context: GameContext) {
        state.phase = phase
        state.fade.invalidate()

        switch phase {
        case .active:
            state.timeScale = 1

            if let playback = state.musicPlayback {
                context.audio.resume(playback)
            } else if let music = state.music {
                state.musicPlayback = context.audio.play(music, looping: true)
            }

        case .background, .inactive:
            state.timeScale = 0
        }
    }

    func fixedUpdate(_ time: FixedTime, context: GameContext) {
        state.player.fixedUpdate(time, context: context)
    }

    func update(_ time: UpdateTime, context: GameContext) {
        state.player.update(time, context: context)
        state.fade.advance(by: time.unscaledDelta)

        switch state.phase {
        case .active:
#if os(macOS)
            let volume = lerp(from: 0.15, to: 1, by: state.fade.progress)
            context.audio.masterVolume = .init(volume)
#else
            if let music = state.musicPlayback {
                context.audio.resume(music)
            }
#endif
        case .inactive, .background:
#if os(macOS)
            let volume = lerp(from: 1.0, to: 0.15, by: state.fade.progress)
            context.audio.masterVolume = .init(volume)
#else
            context.audio.pause(state.musicPlayback)
#endif
        }
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        _ = frame.clear(target: output)

        try state.player.render(
            on: platform,
            output: output,
            frame: frame,
            time: time,
            context: context
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
        var fade: Timer = .init(duration: 1)
        var timeScale = 1.0
        var musicPlayback: Playback?
        var pipeline: RenderPipeline
        var player: Player
        let music: SoundAsset?
        var phase: GamePhase = .active

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
            music = context.assets.load(sound: "music.wav")
        }
    }
}
