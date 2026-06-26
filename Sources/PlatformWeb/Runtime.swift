import GameCore
import JavaScriptKit
import Swift

final class Runtime {
    private var game: Game
    private let renderer: Renderer
    private let audio: Audio

    private let keyboardInput = KeyboardInput()
    private let gamepadInput = GamepadInput()
    private let touchInput = TouchInput()

    private var animationFrameCallback: JSClosure?
    private var lastFrameMilliseconds: Double?
    private var accumulatedTime = 0.0

    init(game: Game) {
        self.game = game
        self.renderer = Renderer(interpolationMode: game.interpolationMode)
        self.audio = Audio()
    }

    private var fixedTimeStep: Double {
        guard game.preferredFps > 0 else {
            return 1.0 / 60.0
        }

        return 1.0 / game.preferredFps
    }

    func start() {
        renderer.configure()
        renderer.loadSpriteTextures(game.spriteAssets)
        audio.configure()
        audio.loadSoundBuffers(game.soundAssets)
        keyboardInput.startListening()
        touchInput.startListening(on: renderer.canvas)

        animationFrameCallback = JSClosure { arguments in
            let timestampMilliseconds = arguments.first?.number ?? 0
            self.renderFrame(timestampMilliseconds: timestampMilliseconds)
            return .undefined
        }

        requestNextFrame()
    }

    private func renderFrame(timestampMilliseconds: Double) {
        let rawDeltaSeconds = lastFrameMilliseconds.map {
            (timestampMilliseconds - $0) / 1000
        } ?? fixedTimeStep
        lastFrameMilliseconds = timestampMilliseconds

        accumulatedTime += max(rawDeltaSeconds, 0)

        while accumulatedTime >= fixedTimeStep {
            game.update(delta: fixedTimeStep, input: inputState)
            accumulatedTime -= fixedTimeStep
        }

        audio.playSounds(game.drainSounds())
        renderer.draw(game: game)

        requestNextFrame()
    }

    private var inputState: Input {
        keyboardInput.state
            .combined(with: gamepadInput.state)
            .combined(with: touchInput.state)
    }

    private func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }
}
