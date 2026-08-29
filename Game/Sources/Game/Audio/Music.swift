import Pixl

struct GameStateHandler {
    private let playback: Playback
    private let mixer: Mixer
    private var fade: Timer = .init(duration: 1)
    private var phase: GamePhase = .active
    private var wasEffectivelyPaused = false
    private var playingVolume: Double
    private var fadeStartVolume: Double
    private var bindings: GameBindings = .init()

    var isPaused = false

    init(context: GameContext) throws {
        mixer = try .init(audio: context.audio, settings: .init())
        playingVolume = .init(context.audio.masterVolume)
        fadeStartVolume = playingVolume

        let sound = try context.assets.load(sound: "music.wav")
        playback = context.audio.prepare(sound)
        playback.loop = true
        playback.bus = mixer.music

        bindings.bind(to: context.inputs)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
        self.phase = phase

        switch phase {
        case .active:
            try? playback.play()
        case .background, .inactive:
            break
        }
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        let shouldPause = isPaused || phase != .active
        if shouldPause != wasEffectivelyPaused {
            fadeStartVolume = .init(context.audio.masterVolume)
            fade.invalidate()
            wasEffectivelyPaused = shouldPause
        }

        fade.advance(by: time.unscaledDelta)
        let volume = lerp(
            from: fadeStartVolume,
            to: shouldPause ? 0.01 : playingVolume,
            by: fade.progress
        )

        if bindings.menu.is(.down) {
            isPaused.toggle()
        }

        context.audio.masterVolume = .init(volume)
        context.pause(shouldPause)
    }
}
