import GameCore
import JavaScriptKit
import Swift

extension Runtime {
    func configureWebGL() {
        guard let canvas else {
            fatalError("Canvas must be configured before WebGL")
        }

        guard let gl = canvas.getContext!("webgl2").object else {
            fatalError("WebGL2 is not available")
        }

        self.gl = gl
        _ = gl.enable!(gl.BLEND)
        _ = gl.blendFunc!(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    }

    func configureSpritePipeline() {
        guard let gl else { return }

        let vertexShader = compileShader(
            type: gl.VERTEX_SHADER,
            source: """
            attribute vec2 a_position;
            uniform vec2 u_resolution;
            uniform vec4 u_rect;
            varying vec2 v_texCoord;

            void main() {
                vec2 pixelPosition = u_rect.xy + (a_position * u_rect.zw);
                vec2 zeroToOne = pixelPosition / u_resolution;
                vec2 clipSpace = (zeroToOne * 2.0) - 1.0;
                v_texCoord = a_position;
                gl_Position = vec4(clipSpace * vec2(1.0, -1.0), 0.0, 1.0);
            }
            """
        )
        let fragmentShader = compileShader(
            type: gl.FRAGMENT_SHADER,
            source: """
            precision mediump float;
            uniform vec4 u_color;
            uniform bool u_useTexture;
            uniform sampler2D u_texture;
            varying vec2 v_texCoord;

            void main() {
                gl_FragColor = u_useTexture ? texture2D(u_texture, v_texCoord) : u_color;
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
        useTextureUniform = gl.getUniformLocation!(program, "u_useTexture")
        textureUniform = gl.getUniformLocation!(program, "u_texture")
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

    func drawSprite(_ sprite: Sprite) {
        switch sprite.material {
        case .color(let color):
            drawSprite(sprite, material: .color(color))
        case .sprite(let spriteID):
            guard let texture = spriteTextures[spriteID] else {
                drawSprite(sprite, material: .color(missingTextureColor))
                return
            }

            drawSprite(sprite, material: .texture(texture))
        }
    }

    private func drawSprite(_ sprite: Sprite, material: RenderMaterial) {
        guard let gl else { return }

        let rect = renderRect(for: sprite)

        _ = gl.useProgram!(shaderProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.uniform2f!(resolutionUniform, game.size.x, game.size.y)
        _ = gl.uniform4f!(rectUniform, rect.x, rect.y, rect.width, rect.height)
        applyMaterial(material, gl: gl)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
    }

    private func applyMaterial(_ material: RenderMaterial, gl: JSObject) {
        switch material {
        case .color(let color):
            _ = gl.uniform4f!(colorUniform, color.red, color.green, color.blue, color.alpha)
            _ = gl.uniform1i!(useTextureUniform, 0)
        case .texture(let texture):
            _ = gl.uniform4f!(colorUniform, 1, 1, 1, 1)
            _ = gl.uniform1i!(useTextureUniform, 1)
            _ = gl.activeTexture!(gl.TEXTURE0)
            _ = gl.bindTexture!(gl.TEXTURE_2D, texture)
            _ = gl.uniform1i!(textureUniform, 0)
        }
    }

    private func renderRect(for sprite: Sprite) -> RenderRect {
        switch game.interpolationMode {
        case .linear:
            return RenderRect(
                x: sprite.position.x,
                y: sprite.position.y,
                width: sprite.size.x,
                height: sprite.size.y
            )
        case .nearest:
            return RenderRect(
                x: sprite.position.x.rounded(),
                y: sprite.position.y.rounded(),
                width: sprite.size.x.rounded(),
                height: sprite.size.y.rounded()
            )
        }
    }
}

private let missingTextureColor = Color(red: 1, green: 0, blue: 1, alpha: 1)

private enum RenderMaterial {
    case color(Color)
    case texture(JSValue)
}

private struct RenderRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
