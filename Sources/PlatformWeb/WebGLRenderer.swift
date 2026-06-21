import GameCore
import JavaScriptKit
import Swift

extension BrowserRuntime {
    func configureWebGL() {
        guard let canvas else {
            fatalError("Canvas must be configured before WebGL")
        }

        guard let gl = canvas.getContext!("webgl2").object else {
            fatalError("WebGL2 is not available")
        }

        self.gl = gl
    }

    func configureQuadPipeline() {
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

    func compileShader(type: JSValue, source: String) -> JSValue {
        guard let gl else { return .undefined }

        let shader = gl.createShader!(type)
        _ = gl.shaderSource!(shader, source)
        _ = gl.compileShader!(shader)

        guard gl.getShaderParameter!(shader, gl.COMPILE_STATUS).boolean == true else {
            fatalError("Unable to compile WebGL shader")
        }

        return shader
    }

    func clearScreen() {
        guard let gl else { return }

        let color = game.clearColor
        _ = gl.clearColor!(color.red, color.green, color.blue, color.alpha)
        _ = gl.clear!(gl.COLOR_BUFFER_BIT)
    }

    func drawQuad(_ quad: Quad) {
        guard let gl else { return }

        let color = quad.color
        let rect = renderRect(for: quad)

        _ = gl.useProgram!(shaderProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.uniform2f!(resolutionUniform, game.size.x, game.size.y)
        _ = gl.uniform4f!(rectUniform, rect.x, rect.y, rect.width, rect.height)
        _ = gl.uniform4f!(colorUniform, color.red, color.green, color.blue, color.alpha)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
    }

    private func renderRect(for quad: Quad) -> RenderRect {
        switch game.interpolationMode {
        case .linear:
            return RenderRect(
                x: quad.position.x,
                y: quad.position.y,
                width: quad.size.x,
                height: quad.size.y
            )
        case .nearest:
            return RenderRect(
                x: quad.position.x.rounded(),
                y: quad.position.y.rounded(),
                width: quad.size.x.rounded(),
                height: quad.size.y.rounded()
            )
        }
    }
}

private struct RenderRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
