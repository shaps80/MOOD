import Swift
import GameCore
import JavaScriptKit

public enum PlatformWeb {
    public static func run() {
        BrowserRuntime(game: Game()).start()
    }
}

private final class BrowserRuntime {
    private var game: Game
    private var animationFrameCallback: JSClosure?
    private var canvas: JSObject?
    private var gl: JSObject?
    private var startMilliseconds: Double = 0

    init(game: Game) {
        self.game = game
    }

    func start() {
        configureCanvas()
        configureWebGL()
        startMilliseconds = nowMilliseconds()

        animationFrameCallback = JSClosure { _ in
            self.tick()
            return .undefined
        }

        requestNextFrame()
    }

    private func tick() {
        let elapsedSeconds = Int((nowMilliseconds() - startMilliseconds) / 1000)
        game.tick(elapsedSeconds: elapsedSeconds)
        resizeCanvasToDisplaySize()
        clearScreen()

        requestNextFrame()
    }

    private func configureCanvas() {
        let document = JSObject.global.document
        guard let canvas = document.getElementById("game").object else {
            fatalError("Missing canvas element with id 'game'")
        }

        self.canvas = canvas
    }

    private func configureWebGL() {
        guard let canvas else {
            fatalError("Canvas must be configured before WebGL")
        }

        guard let gl = canvas.getContext!("webgl2").object else {
            fatalError("WebGL2 is not available")
        }

        self.gl = gl
    }

    private func resizeCanvasToDisplaySize() {
        guard let canvas, let gl else { return }

        let width = JSObject.global.innerWidth.number ?? 0
        let height = JSObject.global.innerHeight.number ?? 0

        if canvas.width.number != width {
            canvas.width = .number(width)
        }

        if canvas.height.number != height {
            canvas.height = .number(height)
        }

        _ = gl.viewport!(0, 0, width, height)
    }

    private func clearScreen() {
        guard let gl else { return }

        let color = game.clearColor
        _ = gl.clearColor!(color.red, color.green, color.blue, color.alpha)
        _ = gl.clear!(gl.COLOR_BUFFER_BIT)
    }

    private func nowMilliseconds() -> Double {
        JSObject.global.Date.now().number ?? 0
    }

    private func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }
}
