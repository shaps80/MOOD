import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let camera: OrthographicCamera = .init(halfHeight: 200)
    private let spriteRenderer: SpriteRenderer
    private let music: Playback
    private let mixer: Mixer
    private var fade: Timer = .init(duration: 1)
    private var player: Player
    private var character: Character
    private var phase: GamePhase = .active
    private var isPaused = false
    private var wasEffectivelyPaused = false
    private var playingVolume: Double
    private var fadeStartVolume: Double
    private var bindings: GameBindings = .init()

    init(context: GameContext) throws {
        mixer = try .init(audio: context.audio, settings: .init())
        playingVolume = .init(context.audio.masterVolume)
        fadeStartVolume = playingVolume
        spriteRenderer = try .init(context: context)

        let sound = try context.assets.load(sound: "music.wav")
        music = context.audio.prepare(sound)
        music.loop = true
        music.bus = mixer.music

        player = try .init(camera: camera, context: context)
        character = try .init(camera: camera, context: context)

        bindings.bind(to: context.inputs)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
        self.phase = phase

        switch phase {
        case .active:
            try? music.play()
        case .background, .inactive:
            break
        }
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        player.fixedUpdate(time, context: context)
        character.fixedUpdate(time, context: context)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        player.update(time, context: context)
        character.update(time, context: context)

        if bindings.menu.is(.down) {
            isPaused.toggle()
        }

        let shouldPause = isPaused || phase != .active
        if shouldPause != wasEffectivelyPaused {
            fadeStartVolume = .init(context.audio.masterVolume)
            fade.invalidate()
            wasEffectivelyPaused = shouldPause
        }

        fade.advance(by: time.unscaledDelta)
        let volume = lerp(
            from: fadeStartVolume,
            to: shouldPause ? 0 : playingVolume,
            by: fade.progress
        )

        context.audio.masterVolume = .init(volume)
        context.pause(shouldPause)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        player.submit(
            to: spriteRenderer,
            output: output
        )
        character.submit(to: spriteRenderer, output: output)

        let pass = frame.clear(target: output)
        spriteRenderer.render(on: pass)

        logMetrics(time)
    }

    private func logMetrics(_ time: RenderTime) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
            time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
        print(time.metrics.summary)
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
