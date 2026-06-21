import GameCore
import JavaScriptKit
import Swift

final class BrowserRuntime {
    let fixedTimeStep = 1.0 / 60.0
    var game: Game
    let keyboardInput = KeyboardInput()
    var animationFrameCallback: JSClosure?
    var canvas: JSObject?
    var gl: JSObject?
    var shaderProgram: JSValue = .undefined
    var positionBuffer: JSValue = .undefined
    var positionAttributeLocation: Int = 0
    var resolutionUniform: JSValue = .undefined
    var rectUniform: JSValue = .undefined
    var colorUniform: JSValue = .undefined
    var lastFrameMilliseconds: Double?
    var accumulatedTime = 0.0

    init(game: Game) {
        self.game = game
    }

    func start() {
        configureCanvas()
        configureWebGL()
        configureQuadPipeline()
        keyboardInput.startListening()

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
            game.update(delta: fixedTimeStep, input: keyboardInput.state)
            accumulatedTime -= fixedTimeStep
        }

        syncCanvasWithGameResolution()
        clearScreen()
        drawQuad(game.player)

        requestNextFrame()
    }

    func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }
}
