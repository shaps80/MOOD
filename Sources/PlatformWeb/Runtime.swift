import GameCore
import JavaScriptKit
import Swift

final class Runtime {
    var game: Game

    // Input
    let keyboardInput = KeyboardInput()
    let gamepadInput = GamepadInput()
    let touchInput = TouchInput()

    // Renderer
    var canvas: JSObject?
    var gl: JSObject?
    var shaderProgram: JSValue = .undefined

    // Positions
    var positionBuffer: JSValue = .undefined
    var positionAttributeLocation: Int = 0

    // Uniforms
    var resolutionUniform: JSValue = .undefined
    var rectUniform: JSValue = .undefined
    var colorUniform: JSValue = .undefined
    var useTextureUniform: JSValue = .undefined
    var textureUniform: JSValue = .undefined

    // Sprites
    var spriteTextures: [SpriteID: JSValue] = [:]
    var spriteImages: [SpriteID: JSObject] = [:]
    var spriteLoadClosures: [SpriteID: JSClosure] = [:]
    var spriteErrorClosures: [SpriteID: JSClosure] = [:]

    // Audio
    var audioContext: JSObject?
    var soundBuffers: [SoundID: JSValue] = [:]
    var soundLoadClosures: [JSClosure] = []

    // Animation
    var animationFrameCallback: JSClosure?
    var lastFrameMilliseconds: Double?
    var accumulatedTime = 0.0

    init(game: Game) {
        self.game = game
    }

    var fixedTimeStep: Double {
        guard game.preferredFps > 0 else {
            return 1.0 / 60.0
        }

        return 1.0 / game.preferredFps
    }

    func start() {
        configureCanvas()
        configureWebGL()
        configureSpritePipeline()
        configureAudio()
        loadSpriteTextures()
        loadSoundBuffers()
        keyboardInput.startListening()
        touchInput.startListening(on: canvas)

        animationFrameCallback = JSClosure { arguments in
            let timestampMilliseconds = arguments.first?.number ?? 0
            self.renderFrame(timestampMilliseconds: timestampMilliseconds)
            return .undefined
        }

        requestNextFrame()
    }

    func renderFrame(timestampMilliseconds: Double) {
        let rawDeltaSeconds = lastFrameMilliseconds.map {
            (timestampMilliseconds - $0) / 1000
        } ?? fixedTimeStep
        lastFrameMilliseconds = timestampMilliseconds

        accumulatedTime += max(rawDeltaSeconds, 0)

        while accumulatedTime >= fixedTimeStep {
            game.update(delta: fixedTimeStep, input: inputState)
            accumulatedTime -= fixedTimeStep
        }

        playSounds(game.drainSounds())
        syncCanvasWithGameResolution()
        clearScreen()
        for sprite in game.sprites {
            drawSprite(sprite)
        }

        requestNextFrame()
    }

    var inputState: Input {
        keyboardInput.state
            .combined(with: gamepadInput.state)
            .combined(with: touchInput.state)
    }

    func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }
}
