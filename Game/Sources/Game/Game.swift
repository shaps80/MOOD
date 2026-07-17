import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let pipeline: RenderPipeline
    private let music: Playback
    private let audio: GameAudio
    private var fade: Timer = .init(duration: 1)
    private var player: Player
    private var phase: GamePhase = .active
    private var previousVolume: Double = 1

    init(context: GameContext) throws {
        audio = try .init(audio: context.audio, settings: .init())
        pipeline = try context.platform.device.makeRenderPipeline(
            .init(
                vertex: .vertex,
                fragment: .fragment,
                vertexLayout: .primitive,
                colorFormat: context.drawableFormat
            )
        )

        let sound = try context.assets.load(sound: "music.wav")
        music = context.audio.prepare(sound)
        music.loop = true
        music.bus = audio.music

        player = try .init(
            pipeline: pipeline,
            audio: audio,
            context: context
        )
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
        self.phase = phase
        fade.invalidate()

        switch phase {
        case .active:
            try? music.play()
        case .background, .inactive:
            previousVolume = .init(context.audio.masterVolume)
        }
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        player.fixedUpdate(time, context: context)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        player.update(time, context: context)
        fade.advance(by: time.unscaledDelta)

        switch phase {
        case .active:
#if os(macOS)
            let volume = lerp(from: 0, to: previousVolume, by: fade.progress)
            context.audio.masterVolume = .init(volume)
#endif
        case .inactive, .background:
#if os(macOS)
            let volume = lerp(from: previousVolume, to: 0, by: fade.progress)
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

        try player.render(
            on: platform,
            output: output,
            frame: frame,
            time: time,
            context: context
        )

        logMetrics(time)
    }

    private func logMetrics(_ time: RenderTime) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
              time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
//        print(time.metrics.summary)
    }
}

extension Game {
    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(width: 800, height: 400),
        )
    }

    static let assetSettings: AssetSettings = .init()
}
