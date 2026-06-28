import Pixl
import JavaScriptKit
import Swift

final class Renderer {
    var canvas: JSObject?
    var gl: JSObject?
    private var shaderProgram: JSValue = .undefined
    private var shapeProgram: JSValue = .undefined
    private var positionBuffer: JSValue = .undefined
    private var instanceBuffer: JSValue = .undefined
    private var shapeInstanceBuffer: JSValue = .undefined
    private var positionAttributeLocation: Int = 0
    private var rectAttributeLocation: Int = 0
    private var textureRectAttributeLocation: Int = 0
    private var colorAttributeLocation: Int = 0
    private var resolutionUniform: JSValue = .undefined
    private var useTextureUniform: JSValue = .undefined
    private var textureUniform: JSValue = .undefined
    private var shapeRectAttributeLocation: Int = 0
    private var shapeInfoAttributeLocation: Int = 0
    private var shapeLineAttributeLocation: Int = 0
    private var shapeFillColorAttributeLocation: Int = 0
    private var shapeStrokeColorAttributeLocation: Int = 0
    private var shapeFlagsAttributeLocation: Int = 0
    private var shapeResolutionUniform: JSValue = .undefined
    private var batchData: [Float] = []
    private var shapeBatchData: [Float] = []
    private var preparedBatches: [PreparedBatch] = []
    var lastCanvasDisplaySize: CanvasDisplaySize?

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
        configureShapePipeline()
    }

    func draw(game: Game) {
        syncCanvasWithGameResolution(game: game)
        clearScreen(color: game.clearColor)

        prepareBatches(game: game)
        uploadBatchInstances()
        uploadShapeBatchInstances()

        for batch in preparedBatches {
            drawBatch(batch, game: game)
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
        applyBlendMode(.normal, gl: gl)
    }

    func configureSpritePipeline() {
        guard let gl else { return }

        let vertexShader = compileShader(
            type: gl.VERTEX_SHADER,
            source: """
            attribute vec2 a_position;
            attribute vec4 a_rect;
            attribute vec4 a_textureRect;
            attribute vec4 a_color;
            uniform vec2 u_resolution;
            varying vec2 v_texCoord;
            varying vec4 v_color;

            void main() {
                vec2 pixelPosition = a_rect.xy + (a_position * a_rect.zw);
                vec2 zeroToOne = pixelPosition / u_resolution;
                vec2 clipSpace = (zeroToOne * 2.0) - 1.0;
                v_texCoord = a_textureRect.xy + (a_position * a_textureRect.zw);
                v_color = a_color;
                gl_Position = vec4(clipSpace * vec2(1.0, -1.0), 0.0, 1.0);
            }
            """
        )
        let fragmentShader = compileShader(
            type: gl.FRAGMENT_SHADER,
            source: """
            precision mediump float;
            uniform bool u_useTexture;
            uniform sampler2D u_texture;
            varying vec2 v_texCoord;
            varying vec4 v_color;

            void main() {
                vec4 source = u_useTexture ? texture2D(u_texture, v_texCoord) : vec4(1.0);
                source *= v_color;
                source.rgb *= source.a;
                gl_FragColor = source;
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
        rectAttributeLocation = Int(gl.getAttribLocation!(program, "a_rect").number ?? 0)
        textureRectAttributeLocation = Int(
            gl.getAttribLocation!(program, "a_textureRect").number ?? 0
        )
        colorAttributeLocation = Int(gl.getAttribLocation!(program, "a_color").number ?? 0)
        resolutionUniform = gl.getUniformLocation!(program, "u_resolution")
        useTextureUniform = gl.getUniformLocation!(program, "u_useTexture")
        textureUniform = gl.getUniformLocation!(program, "u_texture")
        positionBuffer = gl.createBuffer!()
        instanceBuffer = gl.createBuffer!()

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

    func configureShapePipeline() {
        guard let gl else { return }

        let vertexShader = compileShader(
            type: gl.VERTEX_SHADER,
            source: """
            attribute vec2 a_position;
            attribute vec4 a_rect;
            attribute vec4 a_info;
            attribute vec4 a_line;
            attribute vec4 a_fillColor;
            attribute vec4 a_strokeColor;
            attribute vec4 a_flags;
            uniform vec2 u_resolution;
            varying vec2 v_localPosition;
            varying vec2 v_size;
            varying vec4 v_info;
            varying vec4 v_line;
            varying vec4 v_fillColor;
            varying vec4 v_strokeColor;
            varying vec4 v_flags;

            void main() {
                vec2 pixelPosition = a_rect.xy + (a_position * a_rect.zw);
                vec2 zeroToOne = pixelPosition / u_resolution;
                vec2 clipSpace = (zeroToOne * 2.0) - 1.0;
                v_localPosition = a_position * a_rect.zw;
                v_size = a_rect.zw;
                v_info = a_info;
                v_line = a_line;
                v_fillColor = a_fillColor;
                v_strokeColor = a_strokeColor;
                v_flags = a_flags;
                gl_Position = vec4(clipSpace * vec2(1.0, -1.0), 0.0, 1.0);
            }
            """
        )
        let fragmentShader = compileShader(
            type: gl.FRAGMENT_SHADER,
            source: """
            precision mediump float;
            varying vec2 v_localPosition;
            varying vec2 v_size;
            varying vec4 v_info;
            varying vec4 v_line;
            varying vec4 v_fillColor;
            varying vec4 v_strokeColor;
            varying vec4 v_flags;

            float roundedBoxDistance(vec2 p, vec2 size, float radius) {
                vec2 halfSize = size * 0.5;
                vec2 q = abs(p - halfSize) - (halfSize - vec2(radius));
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            }

            float ellipseDistance(vec2 p, vec2 size) {
                vec2 radius = max(size * 0.5, vec2(0.0001));
                vec2 centered = p - radius;
                return (length(centered / radius) - 1.0) * min(radius.x, radius.y);
            }

            float segmentDistance(vec2 p, vec2 a, vec2 b) {
                vec2 pa = p - a;
                vec2 ba = b - a;
                float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
                return length(pa - (ba * h));
            }

            float lineBoxDistance(vec2 p, vec2 a, vec2 b, float width, float cap) {
                vec2 center = (a + b) * 0.5;
                vec2 axis = b - a;
                float len = max(length(axis), 0.0001);
                vec2 dir = axis / len;
                vec2 normal = vec2(-dir.y, dir.x);
                float halfLen = (len * 0.5) + ((cap > 0.5) ? width * 0.5 : 0.0);
                vec2 local = vec2(dot(p - center, dir), dot(p - center, normal));
                vec2 q = abs(local) - vec2(halfLen, width * 0.5);
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
            }

            float coverage(float distance, float antialiased) {
                float hard = step(distance, 0.0);
                float width = max(fwidth(distance), 0.0001);
                float soft = clamp(0.5 - (distance / width), 0.0, 1.0);
                return mix(hard, soft, antialiased);
            }

            void main() {
                float kind = v_info.x;
                float radius = v_info.y;
                float strokeWidth = v_info.z;
                float cap = v_info.w;
                float d = 0.0;

                if (kind < 0.5) {
                    d = roundedBoxDistance(v_localPosition, v_size, 0.0);
                } else if (kind < 1.5) {
                    d = roundedBoxDistance(v_localPosition, v_size, radius);
                } else if (kind < 2.5) {
                    d = ellipseDistance(v_localPosition, v_size);
                } else {
                    if (cap > 1.5) {
                        d = segmentDistance(v_localPosition, v_line.xy, v_line.zw) - (strokeWidth * 0.5);
                    } else {
                        d = lineBoxDistance(v_localPosition, v_line.xy, v_line.zw, strokeWidth, cap);
                    }
                }

                float fillCoverage = coverage(d, v_flags.x) * v_fillColor.a;
                float strokeDistance = abs(d + (strokeWidth * 0.5)) - (strokeWidth * 0.5);
                float strokeCoverage = coverage(strokeDistance, v_flags.y) * v_strokeColor.a;

                if (kind > 2.5) {
                    fillCoverage = 0.0;
                    strokeCoverage = coverage(d, v_flags.y) * v_strokeColor.a;
                }

                vec4 color = vec4(v_fillColor.rgb, 1.0) * fillCoverage;
                color = mix(color, vec4(v_strokeColor.rgb, 1.0) * strokeCoverage, min(strokeCoverage, 1.0));
                color.a = max(fillCoverage, strokeCoverage);
                color.rgb *= color.a;
                gl_FragColor = color;
            }
            """
        )
        let program = gl.createProgram!()

        _ = gl.attachShader!(program, vertexShader)
        _ = gl.attachShader!(program, fragmentShader)
        _ = gl.linkProgram!(program)

        guard gl.getProgramParameter!(program, gl.LINK_STATUS).boolean == true else {
            fatalError("Unable to link WebGL shape shader program")
        }

        shapeProgram = program
        shapeRectAttributeLocation = Int(gl.getAttribLocation!(program, "a_rect").number ?? 0)
        shapeInfoAttributeLocation = Int(gl.getAttribLocation!(program, "a_info").number ?? 0)
        shapeLineAttributeLocation = Int(gl.getAttribLocation!(program, "a_line").number ?? 0)
        shapeFillColorAttributeLocation = Int(
            gl.getAttribLocation!(program, "a_fillColor").number ?? 0
        )
        shapeStrokeColorAttributeLocation = Int(
            gl.getAttribLocation!(program, "a_strokeColor").number ?? 0
        )
        shapeFlagsAttributeLocation = Int(gl.getAttribLocation!(program, "a_flags").number ?? 0)
        shapeResolutionUniform = gl.getUniformLocation!(program, "u_resolution")
        shapeInstanceBuffer = gl.createBuffer!()
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

    private func prepareBatches(game: Game) {
        batchData.removeAll(keepingCapacity: true)
        shapeBatchData.removeAll(keepingCapacity: true)
        preparedBatches.removeAll(keepingCapacity: true)
        batchData.reserveCapacity(game.renderStats.primitiveCount * 12)
        shapeBatchData.reserveCapacity(game.renderStats.primitiveCount * 24)
        preparedBatches.reserveCapacity(game.renderStats.batchCount)

        for batch in game.renderBatches {
            switch batch {
            case .solids(let blendMode, let sprites):
                appendSolidBatch(sprites, blendMode: blendMode, game: game)
            case .sprites(let textureID, let blendMode, let sprites):
                appendSpriteBatch(
                    sprites,
                    textureID: textureID,
                    blendMode: blendMode,
                    game: game
                )
            case .shapes(let blendMode, let shapes):
                appendShapeBatch(shapes, blendMode: blendMode, game: game)
            }
        }
    }

    private func appendSolidBatch(
        _ sprites: [Sprite],
        blendMode: BlendMode,
        game: Game
    ) {
        let startIndex = batchData.count / 12

        for sprite in sprites {
            appendInstance(
                rect: renderRect(for: sprite, game: game),
                textureRect: .full,
                color: resolvedColor(for: sprite)
            )
        }

        appendPreparedBatch(
            material: .color,
            blendMode: blendMode,
            startIndex: startIndex
        )
    }

    private func appendSpriteBatch(
        _ sprites: [Sprite],
        textureID: TextureID,
        blendMode: BlendMode,
        game: Game
    ) {
        guard let texture = spriteTextures[textureID] else {
            let startIndex = batchData.count / 12

            for sprite in sprites {
                appendInstance(
                    rect: renderRect(for: sprite, game: game),
                    textureRect: .full,
                    color: resolvedColor(
                        for: sprite,
                        fallbackColor: .missingTexture
                    )
                )
            }

            appendPreparedBatch(
                material: .color,
                blendMode: blendMode,
                startIndex: startIndex
            )
            return
        }

        let startIndex = batchData.count / 12

        for sprite in sprites {
            guard case .sprite(_, let sourceRect) = sprite.material,
                  let textureRect = textureRect(for: sourceRect, textureID: textureID)
            else {
                continue
            }

            appendInstance(
                rect: renderRect(for: sprite, game: game),
                textureRect: textureRect,
                color: resolvedColor(for: sprite)
            )
        }

        appendPreparedBatch(
            material: .texture(texture),
            blendMode: blendMode,
            startIndex: startIndex
        )
    }

    private func appendPreparedBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int
    ) {
        let instanceCount = (batchData.count / 12) - startIndex

        guard instanceCount > 0 else { return }

        preparedBatches.append(
            .sprites(
                material: material,
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount
            )
        )
    }

    private func appendShapeBatch(
        _ shapes: [ShapePrimitive],
        blendMode: BlendMode,
        game: Game
    ) {
        let startIndex = shapeBatchData.count / 24

        for shape in shapes {
            appendShapeInstance(shape, game: game)
        }

        let instanceCount = (shapeBatchData.count / 24) - startIndex

        guard instanceCount > 0 else { return }

        preparedBatches.append(
            .shapes(
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount
            )
        )
    }

    private func appendInstance(
        rect: RenderRect,
        textureRect: TextureRect,
        color: Color
    ) {
        batchData.append(contentsOf: [
            Float(rect.x),
            Float(rect.y),
            Float(rect.width),
            Float(rect.height),
            Float(textureRect.x),
            Float(textureRect.y),
            Float(textureRect.width),
            Float(textureRect.height),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha)
        ])
    }

    private func appendShapeInstance(_ shape: ShapePrimitive, game: Game) {
        let rect = renderRect(for: shape.bounds, game: game)

        shapeBatchData.append(contentsOf: [
            Float(rect.x),
            Float(rect.y),
            Float(rect.width),
            Float(rect.height),
            Float(shape.kind.rawValue),
            Float(shape.radius),
            Float(shape.strokeWidth),
            Float(shape.lineCap.shaderValue),
            Float(shape.lineStart.x),
            Float(shape.lineStart.y),
            Float(shape.lineEnd.x),
            Float(shape.lineEnd.y),
            Float(shape.fillColor.red),
            Float(shape.fillColor.green),
            Float(shape.fillColor.blue),
            Float(shape.fillColor.alpha),
            Float(shape.strokeColor.red),
            Float(shape.strokeColor.green),
            Float(shape.strokeColor.blue),
            Float(shape.strokeColor.alpha),
            shape.fillAntialiased ? 1 : 0,
            shape.strokeAntialiased ? 1 : 0,
            0,
            0
        ])
    }

    private func uploadBatchInstances() {
        guard let gl else { return }
        guard !batchData.isEmpty else { return }

        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, instanceBuffer)
        _ = gl.bufferData!(gl.ARRAY_BUFFER, JSFloat32Array(batchData), gl.DYNAMIC_DRAW)
    }

    private func uploadShapeBatchInstances() {
        guard let gl else { return }
        guard !shapeBatchData.isEmpty else { return }

        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, shapeInstanceBuffer)
        _ = gl.bufferData!(gl.ARRAY_BUFFER, JSFloat32Array(shapeBatchData), gl.DYNAMIC_DRAW)
    }

    private func drawBatch(_ batch: PreparedBatch, game: Game) {
        switch batch {
        case .sprites(let material, let blendMode, let startIndex, let instanceCount):
            drawSpriteBatch(
                material: material,
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount,
                game: game
            )
        case .shapes(let blendMode, let startIndex, let instanceCount):
            drawShapeBatch(
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount,
                game: game
            )
        }
    }

    private func drawSpriteBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        game: Game
    ) {
        guard let gl else { return }

        _ = gl.useProgram!(shaderProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.vertexAttribDivisor!(positionAttributeLocation, 0)

        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, instanceBuffer)
        _ = gl.enableVertexAttribArray!(rectAttributeLocation)
        _ = gl.vertexAttribPointer!(
            rectAttributeLocation,
            4,
            gl.FLOAT,
            false,
            48,
            startIndex * 48
        )
        _ = gl.vertexAttribDivisor!(rectAttributeLocation, 1)
        _ = gl.enableVertexAttribArray!(textureRectAttributeLocation)
        _ = gl.vertexAttribPointer!(
            textureRectAttributeLocation,
            4,
            gl.FLOAT,
            false,
            48,
            (startIndex * 48) + 16
        )
        _ = gl.vertexAttribDivisor!(textureRectAttributeLocation, 1)
        _ = gl.enableVertexAttribArray!(colorAttributeLocation)
        _ = gl.vertexAttribPointer!(
            colorAttributeLocation,
            4,
            gl.FLOAT,
            false,
            48,
            (startIndex * 48) + 32
        )
        _ = gl.vertexAttribDivisor!(colorAttributeLocation, 1)

        _ = gl.uniform2f!(resolutionUniform, game.logicalResolution.x, game.logicalResolution.y)
        applyBlendMode(blendMode, gl: gl)
        applyMaterial(material, gl: gl)
        _ = gl.drawArraysInstanced!(gl.TRIANGLES, 0, 6, instanceCount)
    }

    private func drawShapeBatch(
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        game: Game
    ) {
        guard let gl else { return }

        _ = gl.useProgram!(shapeProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(positionAttributeLocation)
        _ = gl.vertexAttribPointer!(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.vertexAttribDivisor!(positionAttributeLocation, 0)

        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, shapeInstanceBuffer)
        configureShapeAttribute(shapeRectAttributeLocation, offset: 0, startIndex: startIndex)
        configureShapeAttribute(shapeInfoAttributeLocation, offset: 16, startIndex: startIndex)
        configureShapeAttribute(shapeLineAttributeLocation, offset: 32, startIndex: startIndex)
        configureShapeAttribute(shapeFillColorAttributeLocation, offset: 48, startIndex: startIndex)
        configureShapeAttribute(shapeStrokeColorAttributeLocation, offset: 64, startIndex: startIndex)
        configureShapeAttribute(shapeFlagsAttributeLocation, offset: 80, startIndex: startIndex)

        _ = gl.uniform2f!(
            shapeResolutionUniform,
            game.logicalResolution.x,
            game.logicalResolution.y
        )
        applyBlendMode(blendMode, gl: gl)
        _ = gl.drawArraysInstanced!(gl.TRIANGLES, 0, 6, instanceCount)
    }

    private func configureShapeAttribute(
        _ location: Int,
        offset: Int,
        startIndex: Int
    ) {
        guard let gl else { return }

        _ = gl.enableVertexAttribArray!(location)
        _ = gl.vertexAttribPointer!(
            location,
            4,
            gl.FLOAT,
            false,
            96,
            (startIndex * 96) + offset
        )
        _ = gl.vertexAttribDivisor!(location, 1)
    }

    private func applyMaterial(_ material: RenderMaterial, gl: JSObject) {
        switch material {
        case .color:
            _ = gl.uniform1i!(useTextureUniform, 0)
        case .texture(let texture):
            _ = gl.uniform1i!(useTextureUniform, 1)
            _ = gl.activeTexture!(gl.TEXTURE0)
            _ = gl.bindTexture!(gl.TEXTURE_2D, texture)
            _ = gl.uniform1i!(textureUniform, 0)
        }
    }

    private func applyBlendMode(_ blendMode: BlendMode, gl: JSObject) {
        switch blendMode {
        case .replace:
            _ = gl.disable!(gl.BLEND)
        case .normal:
            _ = gl.enable!(gl.BLEND)
            _ = gl.blendEquation!(gl.FUNC_ADD)
            _ = gl.blendFuncSeparate!(
                gl.ONE,
                gl.ONE_MINUS_SRC_ALPHA,
                gl.ONE,
                gl.ONE_MINUS_SRC_ALPHA
            )
        case .additive:
            _ = gl.enable!(gl.BLEND)
            _ = gl.blendEquation!(gl.FUNC_ADD)
            _ = gl.blendFuncSeparate!(gl.ONE, gl.ONE, gl.ONE, gl.ONE)
        case .multiply:
            _ = gl.enable!(gl.BLEND)
            _ = gl.blendEquation!(gl.FUNC_ADD)
            _ = gl.blendFuncSeparate!(
                gl.DST_COLOR,
                gl.ONE_MINUS_SRC_ALPHA,
                gl.ONE,
                gl.ONE_MINUS_SRC_ALPHA
            )
        case .screen:
            _ = gl.enable!(gl.BLEND)
            _ = gl.blendEquation!(gl.FUNC_ADD)
            _ = gl.blendFuncSeparate!(
                gl.ONE,
                gl.ONE_MINUS_SRC_COLOR,
                gl.ONE,
                gl.ONE_MINUS_SRC_ALPHA
            )
        }
    }

    private func resolvedColor(
        for sprite: Sprite,
        fallbackColor: Color? = nil
    ) -> Color {
        let baseColor: Color

        switch sprite.material {
        case .color(let color):
            baseColor = color
        case .sprite:
            baseColor = fallbackColor ?? .white
        }

        return Color(
            red: baseColor.red * sprite.tint.red,
            green: baseColor.green * sprite.tint.green,
            blue: baseColor.blue * sprite.tint.blue,
            alpha: baseColor.alpha * sprite.tint.alpha * sprite.opacity
        )
    }

    private func renderRect(for rect: Rect, game: Game) -> RenderRect {
        let position = Vec2(
            x: rect.origin.x - game.camera.origin.x,
            y: rect.origin.y - game.camera.origin.y
        )

        switch game.interpolationMode {
        case .linear:
            return RenderRect(
                x: position.x,
                y: position.y,
                width: rect.size.x,
                height: rect.size.y
            )
        case .nearest:
            return RenderRect(
                x: position.x.rounded(),
                y: position.y.rounded(),
                width: rect.size.x.rounded(),
                height: rect.size.y.rounded()
            )
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
    case color
    case texture(JSValue)
}

private enum PreparedBatch {
    case sprites(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int
    )
    case shapes(
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int
    )
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

private extension LineCap {
    var shaderValue: Double {
        switch self {
        case .butt:
            return 0
        case .square:
            return 1
        case .round:
            return 2
        }
    }
}
