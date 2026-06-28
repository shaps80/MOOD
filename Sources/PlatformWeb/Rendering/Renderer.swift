import Pixl
import JavaScriptKit
import Swift

final class Renderer {
    var canvas: JSObject?
    var gl: JSObject?
    private var shaderProgram: JSValue = .undefined
    private var shapeProgram: JSValue = .undefined
    private var presentProgram: JSValue = .undefined
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
    private var sampledUniform: JSValue = .undefined
    private var sampledSceneTextureUniform: JSValue = .undefined
    private var blendModeUniform: JSValue = .undefined
    private var shapePositionAttributeLocation: Int = 0
    private var shapeRectAttributeLocation: Int = 0
    private var shapeInfoAttributeLocation: Int = 0
    private var shapeLineAttributeLocation: Int = 0
    private var shapeFillColorAttributeLocation: Int = 0
    private var shapeStrokeColorAttributeLocation: Int = 0
    private var shapeFlagsAttributeLocation: Int = 0
    private var shapeResolutionUniform: JSValue = .undefined
    private var shapeAAWidthUniform: JSValue = .undefined
    private var shapeSampledUniform: JSValue = .undefined
    private var shapeSampledSceneTextureUniform: JSValue = .undefined
    private var shapeBlendModeUniform: JSValue = .undefined
    private var presentPositionAttributeLocation: Int = 0
    private var presentTextureUniform: JSValue = .undefined
    private var sceneFramebuffer: JSValue = .undefined
    private var sceneTexture: JSValue = .undefined
    private var alternateSceneFramebuffer: JSValue = .undefined
    private var alternateSceneTexture: JSValue = .undefined
    private var sceneTextureSize: Vec2 = .zero
    private var batchData: [Float] = []
    private var shapeBatchData: [Float] = []
    private var preparedBatches: [PreparedBatch] = []
    private var renderPlanner = RenderPlanner()
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
        configurePresentPipeline()
    }

    func draw(game: Game) {
        syncCanvasWithGameResolution(game: game)
        configureSceneTarget(game: game)
        bindSceneTarget(game: game)
        clearScreen(color: game.clearColor)

        let frame = renderPlanner.prepareFrame(
            game: game,
            textureSizes: spriteTextureSizes
        )

        prepareBatches(frame: frame)
        uploadBatchInstances()
        uploadShapeBatchInstances()

        for batch in preparedBatches {
            drawBatch(batch, game: game)
        }

        presentScene()
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
            precision highp float;
            uniform bool u_useTexture;
            uniform bool u_sampled;
            uniform float u_blendMode;
            uniform vec2 u_resolution;
            uniform sampler2D u_texture;
            uniform sampler2D u_sampledSceneTexture;
            varying vec2 v_texCoord;
            varying vec4 v_color;

            \(webBlendShaderSource)

            void main() {
                vec4 source = u_useTexture ? texture2D(u_texture, v_texCoord) : vec4(1.0);
                source *= v_color;
                source.rgb *= source.a;
                gl_FragColor = u_sampled ? compositeSource(source) : source;
            }
            """
        )
        let program = gl.createProgram!()

        _ = gl.attachShader!(program, vertexShader)
        _ = gl.attachShader!(program, fragmentShader)
        _ = gl.linkProgram!(program)

        guard gl.getProgramParameter!(program, gl.LINK_STATUS).boolean == true else {
            let infoLog = gl.getProgramInfoLog!(program).string ?? "No program info log"
            _ = JSObject.global.console.error("Unable to link WebGL shader program: \(infoLog)")
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
        sampledUniform = gl.getUniformLocation!(program, "u_sampled")
        sampledSceneTextureUniform = gl.getUniformLocation!(program, "u_sampledSceneTexture")
        blendModeUniform = gl.getUniformLocation!(program, "u_blendMode")
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
            precision highp float;
            uniform float u_aaWidth;
            uniform bool u_sampled;
            uniform float u_blendMode;
            uniform vec2 u_resolution;
            uniform sampler2D u_sampledSceneTexture;
            varying vec2 v_localPosition;
            varying vec2 v_size;
            varying vec4 v_info;
            varying vec4 v_line;
            varying vec4 v_fillColor;
            varying vec4 v_strokeColor;
            varying vec4 v_flags;

            \(webBlendShaderSource)

            float roundedBoxDistance(vec2 p, vec2 size, float radius) {
                vec2 halfSize = size * 0.5;
                vec2 q = abs(p - halfSize) - (halfSize - vec2(radius));
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            }

            float continuousRoundedBoxDistance(vec2 p, vec2 size, float radius) {
                float r = max(radius, 0.0);
                vec2 halfSize = size * 0.5;
                vec2 q = abs(p - halfSize) - (halfSize - vec2(r));
                vec2 outside = max(q, 0.0);
                float circular = roundedBoxDistance(p, size, r);
                vec2 outside2 = outside * outside;
                vec2 outside4 = outside2 * outside2;
                float continuousDistance = sqrt(sqrt(max(outside4.x + outside4.y, 0.0)))
                    + min(max(q.x, q.y), 0.0) - r;
                return mix(
                    circular,
                    continuousDistance,
                    0.28 * step(0.0001, r)
                );
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
                float width = max(u_aaWidth, 0.0001);
                float soft = clamp(0.5 - (distance / width), 0.0, 1.0);
                return mix(hard, soft, antialiased);
            }

            void main() {
                float kind = v_info.x;
                float radius = v_info.y;
                float strokeWidth = v_info.z;
                float cap = v_info.w;
                float cornerStyle = v_flags.z;
                float d = 0.0;

                if (kind < 0.5) {
                    d = roundedBoxDistance(v_localPosition, v_size, 0.0);
                } else if (kind < 1.5) {
                    float circular = roundedBoxDistance(v_localPosition, v_size, radius);
                    float continuousDistance = continuousRoundedBoxDistance(v_localPosition, v_size, radius);
                    d = mix(circular, continuousDistance, cornerStyle);
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

                vec4 fill = vec4(v_fillColor.rgb * fillCoverage, fillCoverage);
                vec4 stroke = vec4(v_strokeColor.rgb * strokeCoverage, strokeCoverage);
                vec4 color = stroke + (fill * (1.0 - stroke.a));
                gl_FragColor = u_sampled ? compositeSource(color) : color;
            }
            """
        )
        let program = gl.createProgram!()

        _ = gl.attachShader!(program, vertexShader)
        _ = gl.attachShader!(program, fragmentShader)
        _ = gl.linkProgram!(program)

        guard gl.getProgramParameter!(program, gl.LINK_STATUS).boolean == true else {
            let infoLog = gl.getProgramInfoLog!(program).string ?? "No program info log"
            _ = JSObject.global.console.error("Unable to link WebGL shape shader program: \(infoLog)")
            fatalError("Unable to link WebGL shape shader program")
        }

        shapeProgram = program
        shapePositionAttributeLocation = Int(
            gl.getAttribLocation!(program, "a_position").number ?? 0
        )
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
        shapeAAWidthUniform = gl.getUniformLocation!(program, "u_aaWidth")
        shapeSampledUniform = gl.getUniformLocation!(program, "u_sampled")
        shapeSampledSceneTextureUniform = gl.getUniformLocation!(program, "u_sampledSceneTexture")
        shapeBlendModeUniform = gl.getUniformLocation!(program, "u_blendMode")
        shapeInstanceBuffer = gl.createBuffer!()
    }

    func configurePresentPipeline() {
        guard let gl else { return }

        let vertexShader = compileShader(
            type: gl.VERTEX_SHADER,
            source: """
            attribute vec2 a_position;
            varying vec2 v_texCoord;

            void main() {
                vec2 clipSpace = (a_position * 2.0) - 1.0;
                v_texCoord = a_position;
                gl_Position = vec4(clipSpace, 0.0, 1.0);
            }
            """
        )
        let fragmentShader = compileShader(
            type: gl.FRAGMENT_SHADER,
            source: """
            precision mediump float;
            uniform sampler2D u_texture;
            varying vec2 v_texCoord;

            void main() {
                gl_FragColor = texture2D(u_texture, v_texCoord);
            }
            """
        )
        let program = gl.createProgram!()

        _ = gl.attachShader!(program, vertexShader)
        _ = gl.attachShader!(program, fragmentShader)
        _ = gl.linkProgram!(program)

        guard gl.getProgramParameter!(program, gl.LINK_STATUS).boolean == true else {
            let infoLog = gl.getProgramInfoLog!(program).string ?? "No program info log"
            _ = JSObject.global.console.error("Unable to link WebGL present shader program: \(infoLog)")
            fatalError("Unable to link WebGL present shader program")
        }

        presentProgram = program
        presentPositionAttributeLocation = Int(
            gl.getAttribLocation!(program, "a_position").number ?? 0
        )
        presentTextureUniform = gl.getUniformLocation!(program, "u_texture")
    }

    func compileShader(type: JSValue, source: String) -> JSValue {
        guard let gl else { return .undefined }

        let shader = gl.createShader!(type)
        _ = gl.shaderSource!(shader, source)
        _ = gl.compileShader!(shader)

        guard gl.getShaderParameter!(shader, gl.COMPILE_STATUS).boolean == true else {
            let infoLog = gl.getShaderInfoLog!(shader).string ?? "No shader info log"
            _ = JSObject.global.console.error("Unable to compile WebGL shader: \(infoLog)")
            fatalError("Unable to compile WebGL shader")
        }

        return shader
    }

    private func clearScreen(color: Color) {
        guard let gl else { return }

        _ = gl.clearColor!(color.red, color.green, color.blue, color.alpha)
        _ = gl.clear!(gl.COLOR_BUFFER_BIT)
    }

    private func configureSceneTarget(game: Game) {
        guard let gl else { return }

        let width = max(1, game.logicalResolution.x.rounded())
        let height = max(1, game.logicalResolution.y.rounded())
        let size = Vec2(x: width, y: height)

        guard sceneTextureSize != size else { return }

        let sceneTarget = makeSceneTarget(width: width, height: height, gl: gl)
        let alternateTarget = makeSceneTarget(width: width, height: height, gl: gl)
        _ = gl.bindFramebuffer!(gl.FRAMEBUFFER, JSValue.null)

        sceneTexture = sceneTarget.texture
        sceneFramebuffer = sceneTarget.framebuffer
        alternateSceneTexture = alternateTarget.texture
        alternateSceneFramebuffer = alternateTarget.framebuffer
        sceneTextureSize = size
    }

    private func makeSceneTarget(
        width: Double,
        height: Double,
        gl: JSObject
    ) -> (texture: JSValue, framebuffer: JSValue) {
        let texture = gl.createTexture!()
        let framebuffer = gl.createFramebuffer!()

        _ = gl.bindTexture!(gl.TEXTURE_2D, texture)
        configureSceneTextureParameters(gl)
        _ = gl.texImage2D!(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            width,
            height,
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            JSValue.null
        )
        _ = gl.bindFramebuffer!(gl.FRAMEBUFFER, framebuffer)
        _ = gl.framebufferTexture2D!(
            gl.FRAMEBUFFER,
            gl.COLOR_ATTACHMENT0,
            gl.TEXTURE_2D,
            texture,
            0
        )

        return (texture, framebuffer)
    }

    private func configureSceneTextureParameters(_ gl: JSObject) {
        let filter: JSValue

        switch interpolationMode {
        case .linear:
            filter = gl.LINEAR
        case .nearest:
            filter = gl.NEAREST
        }

        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    }

    private func bindSceneTarget(game: Game) {
        guard let gl else { return }

        unbindSceneTextures(gl)
        _ = gl.bindFramebuffer!(gl.FRAMEBUFFER, sceneFramebuffer)
        _ = gl.viewport!(
            0,
            0,
            game.logicalResolution.x.rounded(),
            game.logicalResolution.y.rounded()
        )
    }

    private func presentScene() {
        guard let gl, let displaySize = lastCanvasDisplaySize else { return }

        _ = gl.bindFramebuffer!(gl.FRAMEBUFFER, JSValue.null)
        _ = gl.viewport!(0, 0, displaySize.backingWidth, displaySize.backingHeight)
        _ = gl.disable!(gl.BLEND)
        _ = gl.useProgram!(presentProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(presentPositionAttributeLocation)
        _ = gl.vertexAttribPointer!(presentPositionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.vertexAttribDivisor!(presentPositionAttributeLocation, 0)
        _ = gl.activeTexture!(gl.TEXTURE0)
        _ = gl.bindTexture!(gl.TEXTURE_2D, sceneTexture)
        _ = gl.uniform1i!(presentTextureUniform, 0)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
        unbindSceneTextures(gl)
        applyBlendMode(.normal, gl: gl)
    }

    private func prepareBatches(frame: RenderFrame) {
        batchData.removeAll(keepingCapacity: true)
        shapeBatchData.removeAll(keepingCapacity: true)
        preparedBatches.removeAll(keepingCapacity: true)
        preparedBatches.reserveCapacity(frame.batches.count)

        for batch in frame.batches {
            switch batch {
            case .sprites(let textureID, let blendMode, let instances):
                appendSpriteBatch(
                    instances,
                    textureID: textureID,
                    blendMode: blendMode
                )
            case .shapes(let blendMode, let instances):
                appendShapeBatch(instances, blendMode: blendMode)
            }
        }
    }

    private func appendSpriteBatch(
        _ instances: [SpriteRenderInstance],
        textureID: TextureID,
        blendMode: BlendMode
    ) {
        guard let texture = spriteTextures[textureID] else {
            let startIndex = batchData.count / 12

            for instance in instances {
                appendInstance(
                    rect: instance.rect,
                    textureRect: .full,
                    color: instance.color
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

        for instance in instances {
            appendInstance(
                rect: instance.rect,
                textureRect: instance.textureRect,
                color: instance.color
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
        _ instances: [ShapeRenderInstance],
        blendMode: BlendMode
    ) {
        let startIndex = shapeBatchData.count / 24

        for instance in instances {
            appendShapeInstance(instance)
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
        rect: Rect,
        textureRect: TextureRect,
        color: Color
    ) {
        batchData.append(contentsOf: [
            Float(rect.origin.x),
            Float(rect.origin.y),
            Float(rect.size.x),
            Float(rect.size.y),
            Float(textureRect.origin.x),
            Float(textureRect.origin.y),
            Float(textureRect.size.x),
            Float(textureRect.size.y),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha)
        ])
    }

    private func appendShapeInstance(_ instance: ShapeRenderInstance) {
        shapeBatchData.append(contentsOf: [
            Float(instance.rect.origin.x),
            Float(instance.rect.origin.y),
            Float(instance.rect.size.x),
            Float(instance.rect.size.y),
            Float(instance.info.x),
            Float(instance.info.y),
            Float(instance.info.z),
            Float(instance.info.w),
            Float(instance.line.x),
            Float(instance.line.y),
            Float(instance.line.z),
            Float(instance.line.w),
            Float(instance.fillColor.red),
            Float(instance.fillColor.green),
            Float(instance.fillColor.blue),
            Float(instance.fillColor.alpha),
            Float(instance.strokeColor.red),
            Float(instance.strokeColor.green),
            Float(instance.strokeColor.blue),
            Float(instance.strokeColor.alpha),
            Float(instance.flags.x),
            Float(instance.flags.y),
            Float(instance.flags.z),
            Float(instance.flags.w)
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
            if blendMode.usesSceneSampling {
                copySceneToAlternate(game: game)
                drawSpriteBatch(
                    material: material,
                    blendMode: blendMode,
                    startIndex: startIndex,
                    instanceCount: instanceCount,
                    game: game,
                    sampled: true
                )
                swapSceneTargets()
            } else {
                drawSpriteBatch(
                    material: material,
                    blendMode: blendMode,
                    startIndex: startIndex,
                    instanceCount: instanceCount,
                    game: game,
                    sampled: false
                )
            }
        case .shapes(let blendMode, let startIndex, let instanceCount):
            if blendMode.usesSceneSampling {
                copySceneToAlternate(game: game)
                drawShapeBatch(
                    blendMode: blendMode,
                    startIndex: startIndex,
                    instanceCount: instanceCount,
                    game: game,
                    sampled: true
                )
                swapSceneTargets()
            } else {
                drawShapeBatch(
                    blendMode: blendMode,
                    startIndex: startIndex,
                    instanceCount: instanceCount,
                    game: game,
                    sampled: false
                )
            }
        }
    }

    private func copySceneToAlternate(game: Game) {
        guard let gl else { return }

        unbindSceneTextures(gl)
        _ = gl.bindFramebuffer!(gl.FRAMEBUFFER, alternateSceneFramebuffer)
        _ = gl.viewport!(0, 0, game.logicalResolution.x.rounded(), game.logicalResolution.y.rounded())
        _ = gl.disable!(gl.BLEND)
        _ = gl.useProgram!(presentProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(presentPositionAttributeLocation)
        _ = gl.vertexAttribPointer!(presentPositionAttributeLocation, 2, gl.FLOAT, false, 0, 0)
        _ = gl.vertexAttribDivisor!(presentPositionAttributeLocation, 0)
        _ = gl.activeTexture!(gl.TEXTURE0)
        _ = gl.bindTexture!(gl.TEXTURE_2D, sceneTexture)
        _ = gl.uniform1i!(presentTextureUniform, 0)
        _ = gl.drawArrays!(gl.TRIANGLES, 0, 6)
        _ = gl.bindTexture!(gl.TEXTURE_2D, JSValue.null)
    }

    private func unbindSceneTextures(_ gl: JSObject) {
        _ = gl.activeTexture!(gl.TEXTURE0)
        _ = gl.bindTexture!(gl.TEXTURE_2D, JSValue.null)
        _ = gl.activeTexture!(gl.TEXTURE1)
        _ = gl.bindTexture!(gl.TEXTURE_2D, JSValue.null)
        _ = gl.activeTexture!(gl.TEXTURE0)
    }

    private func swapSceneTargets() {
        swap(&sceneTexture, &alternateSceneTexture)
        swap(&sceneFramebuffer, &alternateSceneFramebuffer)
    }

    private func drawSpriteBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        game: Game,
        sampled: Bool
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
        _ = gl.uniform1i!(sampledUniform, sampled ? 1 : 0)
        _ = gl.uniform1f!(blendModeUniform, Double(blendMode.shaderValue))
        if sampled {
            _ = gl.disable!(gl.BLEND)
            _ = gl.activeTexture!(gl.TEXTURE1)
            _ = gl.bindTexture!(gl.TEXTURE_2D, sceneTexture)
            _ = gl.uniform1i!(sampledSceneTextureUniform, 1)
        } else {
            applyBlendMode(blendMode, gl: gl)
        }
        applyMaterial(material, gl: gl)
        _ = gl.drawArraysInstanced!(gl.TRIANGLES, 0, 6, instanceCount)
    }

    private func drawShapeBatch(
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        game: Game,
        sampled: Bool
    ) {
        guard let gl else { return }

        _ = gl.useProgram!(shapeProgram)
        _ = gl.bindBuffer!(gl.ARRAY_BUFFER, positionBuffer)
        _ = gl.enableVertexAttribArray!(shapePositionAttributeLocation)
        _ = gl.vertexAttribPointer!(
            shapePositionAttributeLocation,
            2,
            gl.FLOAT,
            false,
            0,
            0
        )
        _ = gl.vertexAttribDivisor!(shapePositionAttributeLocation, 0)

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
        _ = gl.uniform1f!(shapeAAWidthUniform, shapeAAWidth())
        _ = gl.uniform1i!(shapeSampledUniform, sampled ? 1 : 0)
        _ = gl.uniform1f!(shapeBlendModeUniform, Double(blendMode.shaderValue))
        if sampled {
            _ = gl.disable!(gl.BLEND)
            _ = gl.activeTexture!(gl.TEXTURE1)
            _ = gl.bindTexture!(gl.TEXTURE_2D, sceneTexture)
            _ = gl.uniform1i!(shapeSampledSceneTextureUniform, 1)
        } else {
            applyBlendMode(blendMode, gl: gl)
        }
        _ = gl.drawArraysInstanced!(gl.TRIANGLES, 0, 6, instanceCount)
    }

    private func shapeAAWidth() -> Double {
        1
    }

    private func configureShapeAttribute(
        _ location: Int,
        offset: Int,
        startIndex: Int
    ) {
        guard let gl else { return }
        guard location >= 0 else { return }

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
        case .overlay,
             .darken,
             .lighten,
             .colorDodge,
             .colorBurn,
             .softLight,
             .hardLight,
             .difference,
             .exclusion,
             .hue,
             .saturation,
             .color,
             .luminosity:
            _ = gl.disable!(gl.BLEND)
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

private let webBlendShaderSource = """
vec3 multiplyBlend(vec3 source, vec3 destination) {
    return source * destination;
}

vec3 screenBlend(vec3 source, vec3 destination) {
    return source + destination - (source * destination);
}

vec3 overlayBlend(vec3 source, vec3 destination) {
    vec3 low = 2.0 * source * destination;
    vec3 high = 1.0 - (2.0 * (1.0 - source) * (1.0 - destination));
    return mix(low, high, step(vec3(0.5), destination));
}

vec3 colorDodgeBlend(vec3 source, vec3 destination) {
    return mix(
        min(destination / max(1.0 - source, 0.0001), 1.0),
        vec3(1.0),
        step(vec3(1.0), source)
    );
}

vec3 colorBurnBlend(vec3 source, vec3 destination) {
    return mix(
        1.0 - min((1.0 - destination) / max(source, 0.0001), 1.0),
        vec3(0.0),
        step(source, vec3(0.0))
    );
}

vec3 softLightBlend(vec3 source, vec3 destination) {
    vec3 d = mix(
        ((16.0 * destination - 12.0) * destination + 4.0) * destination,
        sqrt(destination),
        step(vec3(0.25), destination)
    );
    vec3 low = destination - ((1.0 - (2.0 * source)) * destination * (1.0 - destination));
    vec3 high = destination + (((2.0 * source) - 1.0) * (d - destination));
    return mix(low, high, step(vec3(0.5), source));
}

float hueToRGB(float p, float q, float t) {
    if (t < 0.0) {
        t += 1.0;
    }
    if (t > 1.0) {
        t -= 1.0;
    }
    if (t < 1.0 / 6.0) {
        return p + ((q - p) * 6.0 * t);
    }
    if (t < 1.0 / 2.0) {
        return q;
    }
    if (t < 2.0 / 3.0) {
        return p + ((q - p) * ((2.0 / 3.0) - t) * 6.0);
    }
    return p;
}

vec3 rgbToHSL(vec3 color) {
    float maxChannel = max(color.r, max(color.g, color.b));
    float minChannel = min(color.r, min(color.g, color.b));
    float hue = 0.0;
    float saturation = 0.0;
    float luminosity = (maxChannel + minChannel) * 0.5;

    if (maxChannel != minChannel) {
        float delta = maxChannel - minChannel;
        saturation = luminosity > 0.5
            ? delta / (2.0 - maxChannel - minChannel)
            : delta / (maxChannel + minChannel);

        if (maxChannel == color.r) {
            hue = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
        } else if (maxChannel == color.g) {
            hue = (color.b - color.r) / delta + 2.0;
        } else {
            hue = (color.r - color.g) / delta + 4.0;
        }
        hue /= 6.0;
    }

    return vec3(hue, saturation, luminosity);
}

vec3 hslToRGB(vec3 hsl) {
    if (hsl.y == 0.0) {
        return vec3(hsl.z);
    }

    float q = hsl.z < 0.5
        ? hsl.z * (1.0 + hsl.y)
        : hsl.z + hsl.y - (hsl.z * hsl.y);
    float p = (2.0 * hsl.z) - q;

    return vec3(
        hueToRGB(p, q, hsl.x + (1.0 / 3.0)),
        hueToRGB(p, q, hsl.x),
        hueToRGB(p, q, hsl.x - (1.0 / 3.0))
    );
}

vec3 hslBlend(vec3 source, vec3 destination, float mode) {
    vec3 sourceHSL = rgbToHSL(source);
    vec3 destinationHSL = rgbToHSL(destination);

    if (mode == 14.0) {
        return hslToRGB(vec3(sourceHSL.x, destinationHSL.y, destinationHSL.z));
    }
    if (mode == 15.0) {
        return hslToRGB(vec3(destinationHSL.x, sourceHSL.y, destinationHSL.z));
    }
    if (mode == 16.0) {
        return hslToRGB(vec3(sourceHSL.x, sourceHSL.y, destinationHSL.z));
    }
    return hslToRGB(vec3(destinationHSL.x, destinationHSL.y, sourceHSL.z));
}

vec3 blendColor(float mode, vec3 source, vec3 destination) {
    if (mode == 2.0) {
        return multiplyBlend(source, destination);
    }
    if (mode == 3.0) {
        return screenBlend(source, destination);
    }
    if (mode == 5.0) {
        return overlayBlend(source, destination);
    }
    if (mode == 6.0) {
        return min(source, destination);
    }
    if (mode == 7.0) {
        return max(source, destination);
    }
    if (mode == 8.0) {
        return colorDodgeBlend(source, destination);
    }
    if (mode == 9.0) {
        return colorBurnBlend(source, destination);
    }
    if (mode == 10.0) {
        return softLightBlend(source, destination);
    }
    if (mode == 11.0) {
        return overlayBlend(destination, source);
    }
    if (mode == 12.0) {
        return abs(destination - source);
    }
    if (mode == 13.0) {
        return destination + source - (2.0 * destination * source);
    }
    if (mode >= 14.0 && mode <= 17.0) {
        return hslBlend(source, destination, mode);
    }
    return source;
}

vec4 compositeSource(vec4 source) {
    vec4 destination = texture2D(u_sampledSceneTexture, gl_FragCoord.xy / u_resolution);

    if (u_blendMode == 4.0) {
        return source;
    }
    if (u_blendMode == 1.0) {
        return source + destination;
    }

    vec3 sourceColor = source.a > 0.0 ? source.rgb / source.a : vec3(0.0);
    vec3 destinationColor = destination.a > 0.0 ? destination.rgb / destination.a : vec3(0.0);
    vec3 blendedColor = clamp(blendColor(u_blendMode, sourceColor, destinationColor), 0.0, 1.0);
    float alpha = source.a + (destination.a * (1.0 - source.a));
    vec3 rgb = (blendedColor * source.a) + (destination.rgb * (1.0 - source.a));

    return vec4(rgb, alpha);
}
"""

private let webShapeShaderSource = """
float roundedBoxDistance(vec2 p, vec2 size, float radius) {
    vec2 halfSize = size * 0.5;
    vec2 q = abs(p - halfSize) - (halfSize - vec2(radius));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float continuousRoundedBoxDistance(vec2 p, vec2 size, float radius) {
    float r = max(radius, 0.0);
    vec2 halfSize = size * 0.5;
    vec2 q = abs(p - halfSize) - (halfSize - vec2(r));
    vec2 outside = max(q, 0.0);
    float circular = roundedBoxDistance(p, size, r);
    vec2 outside2 = outside * outside;
    vec2 outside4 = outside2 * outside2;
    float continuousDistance = sqrt(sqrt(max(outside4.x + outside4.y, 0.0)))
        + min(max(q.x, q.y), 0.0) - r;
    return mix(
        circular,
        continuousDistance,
        0.28 * step(0.0001, r)
    );
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
    float width = max(u_aaWidth, 0.0001);
    float soft = clamp(0.5 - (distance / width), 0.0, 1.0);
    return mix(hard, soft, antialiased);
}

vec4 shapeSourceColor() {
    float kind = v_info.x;
    float radius = v_info.y;
    float strokeWidth = v_info.z;
    float cap = v_info.w;
    float cornerStyle = v_flags.z;
    float d = 0.0;

    if (kind < 0.5) {
        d = roundedBoxDistance(v_localPosition, v_size, 0.0);
    } else if (kind < 1.5) {
        float circular = roundedBoxDistance(v_localPosition, v_size, radius);
        float continuousDistance = continuousRoundedBoxDistance(v_localPosition, v_size, radius);
        d = mix(circular, continuousDistance, cornerStyle);
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

    vec4 fill = vec4(v_fillColor.rgb * fillCoverage, fillCoverage);
    vec4 stroke = vec4(v_strokeColor.rgb * strokeCoverage, strokeCoverage);
    return stroke + (fill * (1.0 - stroke.a));
}
"""
