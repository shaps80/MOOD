@preconcurrency import Metal
@preconcurrency import MetalKit
import Pixl
import simd
import Swift

@MainActor
final class Renderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineStates: [BlendMode: MTLRenderPipelineState]
    private let shapePipelineStates: [BlendMode: MTLRenderPipelineState]
    private let presentPipelineState: MTLRenderPipelineState
    private let quadVertexBuffer: MTLBuffer
    private let textureLoader: MTKTextureLoader
    private let nearestSamplerState: MTLSamplerState
    private let linearSamplerState: MTLSamplerState
    private let whiteTexture: MTLTexture
    private let assetResolver: AssetResolver

    private var spriteTextures: [TextureID: MTLTexture] = [:]
    private var spriteTextureSizes: [TextureID: Vec2] = [:]
    private var batchInstances: [BatchInstance] = []
    private var shapeInstances: [ShapeInstance] = []
    private var preparedBatches: [PreparedBatch] = []
    private var renderPlanner = RenderPlanner()
    private var instanceBuffer: MTLBuffer?
    private var instanceBufferCapacity = 0
    private var shapeInstanceBuffer: MTLBuffer?
    private var shapeInstanceBufferCapacity = 0
    private var sceneTexture: MTLTexture?
    private var sceneTextureSize: Vec2 = .zero

    init(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        assetResolver: AssetResolver
    ) {
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        self.pipelineStates = Renderer.makePipelineStates(
            device: device,
            pixelFormat: pixelFormat,
            vertexFunctionName: "spriteVertex",
            fragmentFunctionName: "spriteFragment"
        )
        self.shapePipelineStates = Renderer.makePipelineStates(
            device: device,
            pixelFormat: pixelFormat,
            vertexFunctionName: "shapeVertex",
            fragmentFunctionName: "shapeFragment"
        )
        self.presentPipelineState = Renderer.makePipelineState(
            device: device,
            pixelFormat: pixelFormat,
            vertexFunctionName: "presentVertex",
            fragmentFunctionName: "presentFragment",
            blendMode: .replace
        )
        self.quadVertexBuffer = Renderer.makeQuadVertexBuffer(device: device)
        self.nearestSamplerState = Renderer.makeSamplerState(
            device: device,
            minMagFilter: .nearest
        )
        self.linearSamplerState = Renderer.makeSamplerState(
            device: device,
            minMagFilter: .linear
        )
        self.whiteTexture = Renderer.makeWhiteTexture(device: device)
        self.assetResolver = assetResolver
    }

    func loadSpriteTextures(_ spriteAssets: [SpriteAsset]) {
        for spriteAsset in Set(spriteAssets) {
            loadSpriteTexture(spriteAsset)
        }
    }

    func draw(game: Game, in view: MTKView) {
        guard view.drawableSize.width > 0,
              view.drawableSize.height > 0,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        let sceneTexture = sceneTexture(for: game)
        let scenePassDescriptor = MTLRenderPassDescriptor()
        scenePassDescriptor.colorAttachments[0].texture = sceneTexture
        scenePassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: game.clearColor.red,
            green: game.clearColor.green,
            blue: game.clearColor.blue,
            alpha: game.clearColor.alpha
        )
        scenePassDescriptor.colorAttachments[0].loadAction = .clear
        scenePassDescriptor.colorAttachments[0].storeAction = .store

        guard let sceneEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: scenePassDescriptor
        ) else {
            return
        }

        sceneEncoder.setViewport(
            MTLViewport(
                originX: 0,
                originY: 0,
                width: game.logicalResolution.x.rounded(),
                height: game.logicalResolution.y.rounded(),
                znear: 0,
                zfar: 1
            )
        )
        sceneEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        sceneEncoder.setFragmentSamplerState(
            samplerState(for: game.interpolationMode),
            index: 0
        )

        var resolution = SIMD2<Float>(
            Float(game.logicalResolution.x),
            Float(game.logicalResolution.y)
        )
        sceneEncoder.setVertexBytes(
            &resolution,
            length: MemoryLayout<SIMD2<Float>>.stride,
            index: 1
        )

        let frame = renderPlanner.prepareFrame(
            game: game,
            textureSizes: spriteTextureSizes
        )

        prepareBatches(frame: frame)
        let instanceBuffer = uploadBatchInstances()
        let shapeInstanceBuffer = uploadShapeBatchInstances()

        for batch in preparedBatches {
            drawBatch(
                batch,
                instanceBuffer: instanceBuffer,
                shapeInstanceBuffer: shapeInstanceBuffer,
                renderEncoder: sceneEncoder
            )
        }

        sceneEncoder.endEncoding()

        guard let presentPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        presentPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        presentPassDescriptor.colorAttachments[0].loadAction = .clear

        guard let presentEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: presentPassDescriptor
        ) else {
            return
        }

        let viewport = GameViewport(
            drawableSize: view.drawableSize,
            gameSize: game.logicalResolution
        )

        presentEncoder.setViewport(viewport.metalViewport)
        presentEncoder.setRenderPipelineState(presentPipelineState)
        presentEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        presentEncoder.setFragmentTexture(sceneTexture, index: 0)
        presentEncoder.setFragmentSamplerState(
            samplerState(for: game.interpolationMode),
            index: 0
        )
        presentEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6
        )
        presentEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func sceneTexture(for game: Game) -> MTLTexture {
        let size = Vec2(
            x: max(1, game.logicalResolution.x.rounded()),
            y: max(1, game.logicalResolution.y.rounded())
        )

        if let sceneTexture, sceneTextureSize == size {
            return sceneTexture
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.x),
            height: Int(size.y),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Unable to create Metal scene texture")
        }

        sceneTexture = texture
        sceneTextureSize = size

        return texture
    }

    private func loadSpriteTexture(_ spriteAsset: SpriteAsset) {
        guard let url = assetResolver.url(for: spriteAsset.path) else {
            print("Unable to find sprite asset '\(spriteAsset.path)'")
            return
        }

        do {
            let texture = try textureLoader.newTexture(
                URL: url,
                options: [
                    .origin: MTKTextureLoader.Origin.topLeft,
                    .SRGB: false
                ]
            )

            spriteTextures[spriteAsset.id] = texture
            spriteTextureSizes[spriteAsset.id] = Vec2(
                x: Double(texture.width),
                y: Double(texture.height)
            )
        } catch {
            print("Unable to load sprite asset '\(spriteAsset.path)': \(error)")
        }
    }

    private func prepareBatches(frame: RenderFrame) {
        batchInstances.removeAll(keepingCapacity: true)
        shapeInstances.removeAll(keepingCapacity: true)
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
            let startIndex = batchInstances.count

            for instance in instances {
                batchInstances.append(
                    BatchInstance(
                        rect: instance.rect.uniform,
                        textureRect: TextureRect.full.uniform,
                        color: instance.color.uniform
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

        let startIndex = batchInstances.count

        for instance in instances {
            batchInstances.append(
                BatchInstance(
                    rect: instance.rect.uniform,
                    textureRect: instance.textureRect.uniform,
                    color: instance.color.uniform
                )
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
        let instanceCount = batchInstances.count - startIndex

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
        let startIndex = shapeInstances.count

        for instance in instances {
            shapeInstances.append(shapeInstance(for: instance))
        }

        let instanceCount = shapeInstances.count - startIndex

        guard instanceCount > 0 else { return }

        preparedBatches.append(
            .shapes(
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount
            )
        )
    }

    private func uploadBatchInstances() -> MTLBuffer? {
        guard !batchInstances.isEmpty else { return nil }

        let length = batchInstances.count * MemoryLayout<BatchInstance>.stride

        if instanceBufferCapacity < length {
            guard let buffer = device.makeBuffer(length: length) else {
                return nil
            }

            instanceBuffer = buffer
            instanceBufferCapacity = length
        }

        guard let instanceBuffer else { return nil }

        batchInstances.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }

            instanceBuffer.contents().copyMemory(
                from: source,
                byteCount: bytes.count
            )
        }

        return instanceBuffer
    }

    private func uploadShapeBatchInstances() -> MTLBuffer? {
        guard !shapeInstances.isEmpty else { return nil }

        let length = shapeInstances.count * MemoryLayout<ShapeInstance>.stride

        if shapeInstanceBufferCapacity < length {
            guard let buffer = device.makeBuffer(length: length) else {
                return nil
            }

            shapeInstanceBuffer = buffer
            shapeInstanceBufferCapacity = length
        }

        guard let shapeInstanceBuffer else { return nil }

        shapeInstances.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }

            shapeInstanceBuffer.contents().copyMemory(
                from: source,
                byteCount: bytes.count
            )
        }

        return shapeInstanceBuffer
    }

    private func drawBatch(
        _ batch: PreparedBatch,
        instanceBuffer: MTLBuffer?,
        shapeInstanceBuffer: MTLBuffer?,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        switch batch {
        case .sprites(let material, let blendMode, let startIndex, let instanceCount):
            guard let instanceBuffer else { return }
            drawSpriteBatch(
                material: material,
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount,
                instanceBuffer: instanceBuffer,
                renderEncoder: renderEncoder
            )

        case .shapes(let blendMode, let startIndex, let instanceCount):
            guard let shapeInstanceBuffer else { return }
            drawShapeBatch(
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount,
                instanceBuffer: shapeInstanceBuffer,
                renderEncoder: renderEncoder
            )
        }
    }

    private func drawSpriteBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        instanceBuffer: MTLBuffer,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        var useTexture = material.useTexture

        guard let pipelineState = pipelineStates[blendMode] else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(
            instanceBuffer,
            offset: startIndex * MemoryLayout<BatchInstance>.stride,
            index: 2
        )
        renderEncoder.setFragmentBytes(
            &useTexture,
            length: MemoryLayout<UInt32>.stride,
            index: 0
        )
        renderEncoder.setFragmentTexture(
            material.texture ?? whiteTexture,
            index: 0
        )
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: instanceCount
        )
    }

    private func drawShapeBatch(
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int,
        instanceBuffer: MTLBuffer,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        guard let pipelineState = shapePipelineStates[blendMode] else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(
            instanceBuffer,
            offset: startIndex * MemoryLayout<ShapeInstance>.stride,
            index: 2
        )
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: instanceCount
        )
    }

    private func shapeInstance(for instance: ShapeRenderInstance) -> ShapeInstance {
        ShapeInstance(
            rect: instance.rect.uniform,
            info: SIMD4(
                Float(instance.info.x),
                Float(instance.info.y),
                Float(instance.info.z),
                Float(instance.info.w)
            ),
            line: SIMD4(
                Float(instance.line.x),
                Float(instance.line.y),
                Float(instance.line.z),
                Float(instance.line.w)
            ),
            fillColor: instance.fillColor.uniform,
            strokeColor: instance.strokeColor.uniform,
            flags: SIMD4(
                Float(instance.flags.x),
                Float(instance.flags.y),
                Float(instance.flags.z),
                Float(instance.flags.w)
            )
        )
    }

    private func samplerState(
        for interpolationMode: InterpolationMode
    ) -> MTLSamplerState {
        switch interpolationMode {
        case .linear:
            return linearSamplerState
        case .nearest:
            return nearestSamplerState
        }
    }

    private static func makePipelineStates(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        vertexFunctionName: String,
        fragmentFunctionName: String
    ) -> [BlendMode: MTLRenderPipelineState] {
        Dictionary(
            uniqueKeysWithValues: [
                .normal,
                .additive,
                .multiply,
                .screen,
                .replace
            ].map { blendMode in
                (
                    blendMode,
                    makePipelineState(
                        device: device,
                        pixelFormat: pixelFormat,
                        vertexFunctionName: vertexFunctionName,
                        fragmentFunctionName: fragmentFunctionName,
                        blendMode: blendMode
                    )
                )
            }
        )
    }

    private static func makePipelineState(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        vertexFunctionName: String,
        fragmentFunctionName: String,
        blendMode: BlendMode
    ) -> MTLRenderPipelineState {
        do {
            let library = try device.makeLibrary(
                source: metalShaderSource,
                options: nil
            )
            let descriptor = MTLRenderPipelineDescriptor()

            descriptor.vertexFunction = library.makeFunction(
                name: vertexFunctionName
            )
            descriptor.fragmentFunction = library.makeFunction(
                name: fragmentFunctionName
            )
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            configureBlendMode(blendMode, descriptor: descriptor)

            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Unable to create Metal sprite pipeline: \(error)")
        }
    }

    private static func configureBlendMode(
        _ blendMode: BlendMode,
        descriptor: MTLRenderPipelineDescriptor
    ) {
        guard let attachment = descriptor.colorAttachments[0] else { return }

        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add

        switch blendMode {
        case .replace:
            attachment.isBlendingEnabled = false
        case .normal:
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .additive:
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .one
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .one
        case .multiply:
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .destinationColor
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .screen:
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceColor
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
    }

    private static func makeQuadVertexBuffer(device: MTLDevice) -> MTLBuffer {
        let vertices: [SIMD2<Float>] = [
            SIMD2(0, 0),
            SIMD2(1, 0),
            SIMD2(0, 1),
            SIMD2(0, 1),
            SIMD2(1, 0),
            SIMD2(1, 1)
        ]

        return vertices.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress,
                  let buffer = device.makeBuffer(
                    bytes: baseAddress,
                    length: bytes.count
                  )
            else {
                fatalError("Unable to create Metal quad vertex buffer")
            }

            return buffer
        }
    }

    private static func makeSamplerState(
        device: MTLDevice,
        minMagFilter: MTLSamplerMinMagFilter
    ) -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()

        descriptor.minFilter = minMagFilter
        descriptor.magFilter = minMagFilter
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge

        guard let samplerState = device.makeSamplerState(descriptor: descriptor) else {
            fatalError("Unable to create Metal sampler state")
        }

        return samplerState
    }

    private static func makeWhiteTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        let pixel: [UInt8] = [255, 255, 255, 255]

        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Unable to create Metal fallback texture")
        }

        pixel.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }

            texture.replace(
                region: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: 4
            )
        }

        return texture
    }
}

private enum RenderMaterial {
    case color
    case texture(MTLTexture)

    var texture: MTLTexture? {
        switch self {
        case .color:
            return nil
        case .texture(let texture):
            return texture
        }
    }

    var useTexture: UInt32 {
        switch self {
        case .color:
            return 0
        case .texture:
            return 1
        }
    }
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

private struct BatchInstance {
    let rect: SIMD4<Float>
    let textureRect: SIMD4<Float>
    let color: SIMD4<Float>
}

private struct ShapeInstance {
    let rect: SIMD4<Float>
    let info: SIMD4<Float>
    let line: SIMD4<Float>
    let fillColor: SIMD4<Float>
    let strokeColor: SIMD4<Float>
    let flags: SIMD4<Float>
}

private extension Color {
    var uniform: SIMD4<Float> {
        SIMD4(
            Float(red),
            Float(green),
            Float(blue),
            Float(alpha)
        )
    }
}

private extension Rect {
    var uniform: SIMD4<Float> {
        SIMD4(
            Float(origin.x),
            Float(origin.y),
            Float(size.x),
            Float(size.y)
        )
    }
}

private extension TextureRect {
    var uniform: SIMD4<Float> {
        SIMD4(
            Float(origin.x),
            Float(origin.y),
            Float(size.x),
            Float(size.y)
        )
    }
}

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct ShapeVertexOut {
    float4 position [[position]];
    float2 localPosition;
    float2 size;
    float4 info;
    float4 line;
    float4 fillColor;
    float4 strokeColor;
    float4 flags;
};

struct PresentVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct BatchInstance {
    float4 rect;
    float4 textureRect;
    float4 color;
};

struct ShapeInstance {
    float4 rect;
    float4 info;
    float4 line;
    float4 fillColor;
    float4 strokeColor;
    float4 flags;
};

vertex PresentVertexOut presentVertex(
    uint vertexID [[vertex_id]],
    constant float2 *positions [[buffer(0)]]
) {
    float2 unitPosition = positions[vertexID];
    float2 clipSpace = (unitPosition * 2.0) - 1.0;

    PresentVertexOut out;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.texCoord = unitPosition;
    return out;
}

fragment float4 presentFragment(
    PresentVertexOut in [[stage_in]],
    texture2d<float> sceneTexture [[texture(0)]],
    sampler sceneSampler [[sampler(0)]]
) {
    return sceneTexture.sample(sceneSampler, in.texCoord);
}

vertex VertexOut spriteVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2 *positions [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]],
    constant BatchInstance *instances [[buffer(2)]]
) {
    BatchInstance instance = instances[instanceID];
    float2 unitPosition = positions[vertexID];
    float2 pixelPosition = instance.rect.xy + (unitPosition * instance.rect.zw);
    float2 zeroToOne = pixelPosition / resolution;
    float2 clipSpace = (zeroToOne * 2.0) - 1.0;

    VertexOut out;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.texCoord = instance.textureRect.xy + (unitPosition * instance.textureRect.zw);
    out.color = instance.color;
    return out;
}

fragment float4 spriteFragment(
    VertexOut in [[stage_in]],
    constant uint &useTexture [[buffer(0)]],
    texture2d<float> spriteTexture [[texture(0)]],
    sampler spriteSampler [[sampler(0)]]
) {
    float4 source = float4(1.0);

    if (useTexture != 0) {
        source = spriteTexture.sample(spriteSampler, in.texCoord);
    }

    source *= in.color;
    source.rgb *= source.a;
    return source;
}

vertex ShapeVertexOut shapeVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2 *positions [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]],
    constant ShapeInstance *instances [[buffer(2)]]
) {
    ShapeInstance instance = instances[instanceID];
    float2 unitPosition = positions[vertexID];
    float2 pixelPosition = instance.rect.xy + (unitPosition * instance.rect.zw);
    float2 zeroToOne = pixelPosition / resolution;
    float2 clipSpace = (zeroToOne * 2.0) - 1.0;

    ShapeVertexOut out;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.localPosition = unitPosition * instance.rect.zw;
    out.size = instance.rect.zw;
    out.info = instance.info;
    out.line = instance.line;
    out.fillColor = instance.fillColor;
    out.strokeColor = instance.strokeColor;
    out.flags = instance.flags;
    return out;
}

float roundedBoxDistance(float2 p, float2 size, float radius) {
    float2 halfSize = size * 0.5;
    float2 q = abs(p - halfSize) - (halfSize - float2(radius));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float continuousRoundedBoxDistance(float2 p, float2 size, float radius) {
    float r = max(radius, 0.0);
    float2 halfSize = size * 0.5;
    float2 q = abs(p - halfSize) - (halfSize - float2(r));
    float2 outside = max(q, 0.0);
    float circular = roundedBoxDistance(p, size, r);
    float2 outside2 = outside * outside;
    float2 outside4 = outside2 * outside2;
    float continuousDistance = sqrt(sqrt(max(outside4.x + outside4.y, 0.0)))
        + min(max(q.x, q.y), 0.0) - r;
    return mix(
        circular,
        continuousDistance,
        0.28 * step(0.0001, r)
    );
}

float ellipseDistance(float2 p, float2 size) {
    float2 radius = max(size * 0.5, float2(0.0001));
    float2 centered = p - radius;
    return (length(centered / radius) - 1.0) * min(radius.x, radius.y);
}

float segmentDistance(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - (ba * h));
}

float lineBoxDistance(float2 p, float2 a, float2 b, float width, float cap) {
    float2 center = (a + b) * 0.5;
    float2 axis = b - a;
    float len = max(length(axis), 0.0001);
    float2 dir = axis / len;
    float2 normal = float2(-dir.y, dir.x);
    float halfLen = (len * 0.5) + ((cap > 0.5) ? width * 0.5 : 0.0);
    float2 local = float2(dot(p - center, dir), dot(p - center, normal));
    float2 q = abs(local) - float2(halfLen, width * 0.5);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float coverage(float distance, float antialiased) {
    float hard = step(distance, 0.0);
    float width = max(fwidth(distance), 0.0001);
    float soft = clamp(0.5 - (distance / width), 0.0, 1.0);
    return mix(hard, soft, antialiased);
}

fragment float4 shapeFragment(ShapeVertexOut in [[stage_in]]) {
    float kind = in.info.x;
    float radius = in.info.y;
    float strokeWidth = in.info.z;
    float cap = in.info.w;
    float cornerStyle = in.flags.z;
    float d = 0.0;

    if (kind < 0.5) {
        d = roundedBoxDistance(in.localPosition, in.size, 0.0);
    } else if (kind < 1.5) {
        float circular = roundedBoxDistance(in.localPosition, in.size, radius);
        float continuousDistance = continuousRoundedBoxDistance(in.localPosition, in.size, radius);
        d = mix(circular, continuousDistance, cornerStyle);
    } else if (kind < 2.5) {
        d = ellipseDistance(in.localPosition, in.size);
    } else {
        if (cap > 1.5) {
            d = segmentDistance(in.localPosition, in.line.xy, in.line.zw) - (strokeWidth * 0.5);
        } else {
            d = lineBoxDistance(in.localPosition, in.line.xy, in.line.zw, strokeWidth, cap);
        }
    }

    float fillCoverage = coverage(d, in.flags.x) * in.fillColor.a;
    float strokeDistance = abs(d + (strokeWidth * 0.5)) - (strokeWidth * 0.5);
    float strokeCoverage = coverage(strokeDistance, in.flags.y) * in.strokeColor.a;

    if (kind > 2.5) {
        fillCoverage = 0.0;
        strokeCoverage = coverage(d, in.flags.y) * in.strokeColor.a;
    }

    float4 fill = float4(in.fillColor.rgb * fillCoverage, fillCoverage);
    float4 stroke = float4(in.strokeColor.rgb * strokeCoverage, strokeCoverage);
    float4 color = stroke + (fill * (1.0 - stroke.a));
    return color;
}
"""
