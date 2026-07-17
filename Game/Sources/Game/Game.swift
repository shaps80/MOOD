import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let state: State
    private let audio: Audio

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
        self.state = try .init(context: context)
        self.audio = context.audio
    }

    func didEnter(_ phase: GamePhase, context: GameContext) {
        state.phase = phase
        state.fade.invalidate()

        switch phase {
        case .active:
            if let playback = state.musicPlayback {
                context.audio.resume(playback)
            } else if let music = state.music {
                state.musicPlayback = context.audio.play(music, looping: true)
            }

        case .background, .inactive:
            break
        }
    }

    func fixedUpdate(_ time: FixedTime, lanes: Lanes) {
        state.player.fixedUpdate(time, lanes: lanes)
    }

    func update(_ time: UpdateTime, lanes: Lanes) {
        state.player.update(time, lanes: lanes)
        state.fade.advance(by: time.deltaSeconds)

        switch state.phase {
        case .active:
            let volume = lerp(from: 0.15, to: 1, by: state.fade.progress)
            audio.setMasterVolume(.init(volume))
        case .inactive, .background:
            let volume = lerp(from: 1.0, to: 0.15, by: state.fade.progress)
            audio.setMasterVolume(.init(volume))
        }
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
        var fade: Timer = .init(duration: 1)
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
