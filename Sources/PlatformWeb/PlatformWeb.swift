import Swift
import GameCore
import JavaScriptKit

public enum PlatformWeb {
    public static func run() {
        BrowserRuntime(game: Game()).start()
    }
}

private final class BrowserRuntime {
    private let fixedTimeStep = 1.0 / 60.0
    private var game: Game
    private var animationFrameCallback: JSClosure?
    private var canvas: JSObject?
    private var gl: JSObject?
    private var shaderProgram: JSValue = .undefined
    private var positionBuffer: JSValue = .undefined
    private var positionAttributeLocation: Int = 0
    private var resolutionUniform: JSValue = .undefined
    private var rectUniform: JSValue = .undefined
    private var colorUniform: JSValue = .undefined
    private var lastFrameMilliseconds: Double?
    private var accumulatedTime = 0.0

    init(game: Game) {
        self.game = game
    }

    func start() {
        configureCanvas()
        configureWebGL()
        configureQuadPipeline()

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
            game.update(delta: fixedTimeStep)
            accumulatedTime -= fixedTimeStep
        }

        syncCanvasSize()
        clearScreen()
        drawQuad(game.player)

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

    private func configureQuadPipeline() {
        guard let gl else { return }

        let vertexShader = compileShader(
            type: gl.VERTEX_SHADER,
            source: """
            attribute vec2 a_position;
            uniform vec2 u_resolution;
            uniform vec4 u_rect;

            void main() {
                vec2 pixelPosition = u_rect.xy + (a_position * u_rect.zw);
                vec2 zeroToOne = pixelPosition / u_resolution;
                vec2 clipSpace = (zeroToOne * 2.0) - 1.0;
                gl_Position = vec4(clipSpace * vec2(1.0, -1.0), 0.0, 1.0);
            }
            """
        )
        let fragmentShader = compileShader(
            type: gl.FRAGMENT_SHADER,
            source: """
            precision mediump float;
            uniform vec4 u_color;

            void main() {
                gl_FragColor = u_color;
            }
            """
        )
        let program = gl.createProgram!()

        _ = gl.attachShader!(program, vertexShader)
        _ = gl.attachShader!(program, fragmentShader)
        _ = gl.linkProgram!(program)

        guard gl.getProgramParameter!(program, gl.LINK_STATUS).boolean == true else {
            fatalError("Unable to link WebGL shader program")
        }

        shaderProgram = program
        positionAttributeLocation = Int(gl.getAttribLocation!(program, "a_position").number ?? 0)
        resolutionUniform = gl.getUniformLocation!(program, "u_resolution")
        rectUniform = gl.getUniformLocation!(program, "u_rect")
        colorUniform = gl.getUniformLocation!(program, "u_color")
        positionBuffer = gl.createBuffer!()

        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)

        let vertices = JSFloat32Array(
            [
                0, 0,
                1, 0,
                0, 1,
                0, 1,
                1, 0,
                1, 1
            ]
        )
        _ = gl.bufferData!(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW)
    }

    private func compileShader(type: JSValue, source: String) -> JSValue {
        guard let gl else { return .undefined }

        let shader = gl.createShader!(type)
        _ = gl.shaderSource!(shader, source)
        _ = gl.compileShader!(shader)

        guard gl.getShaderParameter!(shader, gl.COMPILE_STATUS).boolean == true else {
            fatalError("Unable to compile WebGL shader")
        }

        return shader
    }

    private func syncCanvasSize() {
        guard let canvas, let gl else { return }

        if canvas.width.number != game.size.x {
            canvas.width = .number(game.size.x)
        }

        if canvas.height.number != game.size.y {
            canvas.height = .number(game.size.y)
        }

        fitCanvasToViewport(canvas)
        _ = gl.viewport!(0, 0, game.size.x, game.size.y)
    }

    private func fitCanvasToViewport(_ canvas: JSObject) {
        let viewportWidth = JSObject.global.innerWidth.number ?? game.size.x
        let viewportHeight = JSObject.global.innerHeight.number ?? game.size.y
        let scale = min(viewportWidth / game.size.x, viewportHeight / game.size.y)
        let displayWidth = game.size.x * scale
        let displayHeight = game.size.y * scale

        canvas.style.width = .string("\(displayWidth)px")
        canvas.style.height = .string("\(displayHeight)px")
    }

    private func clearScreen() {
        guard let gl else { return }

        let color = game.clearColor
        _ = gl.clearColor!(color.red, color.green, color.blue, color.alpha)
        _ = gl.clear!(gl.COLOR_BUFFER_BIT)
    }

    private func drawQuad(_ quad: Quad) {
        guard let gl else { return }

        let color = quad.color

        _ = gl.useProgram!(shaderProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.uniform2f!(resolutionUniform, game.size.x, game.size.y)
        _ = gl.uniform4f!(rectUniform, quad.position.x, quad.position.y, quad.size.x, quad.size.y)
        _ = gl.uniform4f!(colorUniform, color.red, color.green, color.blue, color.alpha)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
    }

    private func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }
}
