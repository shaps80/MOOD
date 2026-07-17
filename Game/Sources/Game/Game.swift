import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let state: State
    private let pipeline: RenderPipeline
    private let music: Playback
    private let audio: GameAudio

    init(context: GameContext) throws {
        audio = try .init(audio: context.audio, settings: .init())
        pipeline = try context.platform.device.makeRenderPipeline(
            .init(
                vertex: .vertex,
                fragment: .fragment,
                vertexLayout: .primitive,
                colorFormat: context.renderSettings.drawableFormat
            )
        )

        let sound = try context.assets.load(sound: "music.wav")
        music = context.audio.prepare(sound)
        music.loop = true
        music.bus = audio.music

        self.state = try .init(
            pipeline: pipeline,
            audio: audio,
            context: context
        )
    }

    func didEnter(_ phase: GamePhase, context: GameContext) {
        state.phase = phase
        state.fade.invalidate()

        switch phase {
        case .active:
            do {
                try music.play()
            } catch {
                print("Unable to play music: \(error)")
            }
            state.timeScale = 1

        case .background, .inactive:
#if os(wasi)
            music.pause()
#endif
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
#endif
        case .inactive, .background:
#if os(macOS)
            let volume = lerp(from: 1.0, to: 0.15, by: state.fade.progress)
            context.audio.masterVolume = .init(volume)
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

extension Game {
    private final class State: @unchecked Sendable {
        var metricsElapsed = 0.0
        var fade: Timer = .init(duration: 1)
        var timeScale = 1.0
        var player: Player
        var phase: GamePhase = .active

        init(
            pipeline: RenderPipeline,
            audio: GameAudio,
            context: GameContext
        ) throws {
            player = try .init(
                pipeline: pipeline,
                audio: audio,
                context: context
            )
        }
    }

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(width: 800, height: 400),
        )
    }

    static let assetSettings: AssetSettings = .init()
}
