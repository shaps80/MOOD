import GameCore
import JavaScriptKit
import Swift

final class Renderer {
    var canvas: JSObject?
    var gl: JSObject?
    private var shaderProgram: JSValue = .undefined
    private var positionBuffer: JSValue = .undefined
    private var positionAttributeLocation: Int = 0
    private var resolutionUniform: JSValue = .undefined
    private var rectUniform: JSValue = .undefined
    private var colorUniform: JSValue = .undefined
    private var useTextureUniform: JSValue = .undefined
    private var textureUniform: JSValue = .undefined
    private var textureRectUniform: JSValue = .undefined

    var spriteTextures: [TextureID: JSValue] = [:]
    var spriteTextureSizes: [TextureID: Vec2] = [:]
    var spriteImages: [TextureID: JSObject] = [:]
    var spriteLoadClosures: [TextureID: JSClosure] = [:]
    var spriteErrorClosures: [TextureID: JSClosure] = [:]
    let interpolationMode: InterpolationMode

    init(interpolationMode: InterpolationMode) {
        self.interpolationMode = interpolationMode
    }

    func configure() {
        configureCanvas()
        configureWebGL()
        configureSpritePipeline()
    }

    func draw(game: Game) {
        syncCanvasWithGameResolution(game: game)
        clearScreen(color: game.clearColor)

        for sprite in game.sprites {
            drawSprite(sprite, game: game)
        }
    }

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
            uniform vec4 u_textureRect;
            varying vec2 v_texCoord;

            void main() {
                vec2 pixelPosition = u_rect.xy + (a_position * u_rect.zw);
                vec2 zeroToOne = pixelPosition / u_resolution;
                vec2 clipSpace = (zeroToOne * 2.0) - 1.0;
                v_texCoord = u_textureRect.xy + (a_position * u_textureRect.zw);
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
        textureRectUniform = gl.getUniformLocation!(program, "u_textureRect")
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

    private func clearScreen(color: Color) {
        guard let gl else { return }

        _ = gl.clearColor!(color.red, color.green, color.blue, color.alpha)
        _ = gl.clear!(gl.COLOR_BUFFER_BIT)
    }

    private func drawSprite(_ sprite: Sprite, game: Game) {
        switch sprite.material {
        case .color(let color):
            drawSprite(sprite, material: .color(color), game: game)
        case .sprite(let textureID, let sourceRect):
            guard let texture = spriteTextures[textureID],
                  let textureRect = textureRect(for: sourceRect, textureID: textureID) else {
                drawSprite(sprite, material: .color(.missingTexture), game: game)
                return
            }

            drawSprite(sprite, material: .texture(texture, textureRect), game: game)
        }
    }

    private func drawSprite(_ sprite: Sprite, material: RenderMaterial, game: Game) {
        guard let gl else { return }

        let rect = renderRect(for: sprite, game: game)

        _ = gl.useProgram!(shaderProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.uniform2f!(resolutionUniform, game.logicalResolution.x, game.logicalResolution.y)
        _ = gl.uniform4f!(rectUniform, rect.x, rect.y, rect.width, rect.height)
        applyMaterial(material, gl: gl)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
    }

    private func applyMaterial(_ material: RenderMaterial, gl: JSObject) {
        switch material {
        case .color(let color):
            _ = gl.uniform4f!(colorUniform, color.red, color.green, color.blue, color.alpha)
            _ = gl.uniform1i!(useTextureUniform, 0)
            _ = gl.uniform4f!(textureRectUniform, 0, 0, 1, 1)
        case .texture(let texture, let textureRect):
            _ = gl.uniform4f!(colorUniform, 1, 1, 1, 1)
            _ = gl.uniform1i!(useTextureUniform, 1)
            _ = gl.uniform4f!(
                textureRectUniform,
                textureRect.x,
                textureRect.y,
                textureRect.width,
                textureRect.height
            )
            _ = gl.activeTexture!(gl.TEXTURE0)
            _ = gl.bindTexture!(gl.TEXTURE_2D, texture)
            _ = gl.uniform1i!(textureUniform, 0)
        }
    }

    private func textureRect(for sourceRect: Rect?, textureID: TextureID) -> TextureRect? {
        guard let sourceRect else {
            return .full
        }

        guard let textureSize = spriteTextureSizes[textureID],
              textureSize.x > 0,
              textureSize.y > 0 else {
            return nil
        }

        return TextureRect(
            x: sourceRect.origin.x / textureSize.x,
            y: sourceRect.origin.y / textureSize.y,
            width: sourceRect.size.x / textureSize.x,
            height: sourceRect.size.y / textureSize.y
        )
    }

    private func renderRect(for sprite: Sprite, game: Game) -> RenderRect {
        let position = Vec2(
            x: sprite.position.x - game.camera.origin.x,
            y: sprite.position.y - game.camera.origin.y
        )

        switch game.interpolationMode {
        case .linear:
            return RenderRect(
                x: position.x,
                y: position.y,
                width: sprite.size.x,
                height: sprite.size.y
            )
        case .nearest:
            return RenderRect(
                x: position.x.rounded(),
                y: position.y.rounded(),
                width: sprite.size.x.rounded(),
                height: sprite.size.y.rounded()
            )
        }
    }
}

private enum RenderMaterial {
    case color(Color)
    case texture(JSValue, TextureRect)
}

private struct RenderRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct TextureRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let full = TextureRect(x: 0, y: 0, width: 1, height: 1)
}
