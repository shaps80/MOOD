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
    private let quadVertexBuffer: MTLBuffer
    private let textureLoader: MTKTextureLoader
    private let nearestSamplerState: MTLSamplerState
    private let linearSamplerState: MTLSamplerState
    private let whiteTexture: MTLTexture
    private let assetResolver: AssetResolver

    private var spriteTextures: [TextureID: MTLTexture] = [:]
    private var spriteTextureSizes: [TextureID: Vec2] = [:]
    private var batchInstances: [BatchInstance] = []
    private var preparedBatches: [PreparedBatch] = []
    private var instanceBuffer: MTLBuffer?
    private var instanceBufferCapacity = 0

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
            pixelFormat: pixelFormat
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
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: game.clearColor.red,
            green: game.clearColor.green,
            blue: game.clearColor.blue,
            alpha: game.clearColor.alpha
        )
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            return
        }

        let viewport = GameViewport(
            drawableSize: view.drawableSize,
            gameSize: game.logicalResolution
        )

        renderEncoder.setViewport(viewport.metalViewport)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(
            samplerState(for: game.interpolationMode),
            index: 0
        )

        var resolution = SIMD2<Float>(
            Float(game.logicalResolution.x),
            Float(game.logicalResolution.y)
        )
        renderEncoder.setVertexBytes(
            &resolution,
            length: MemoryLayout<SIMD2<Float>>.stride,
            index: 1
        )

        prepareBatches(game: game)
        if let instanceBuffer = uploadBatchInstances() {
            for batch in preparedBatches {
                drawBatch(
                    batch,
                    instanceBuffer: instanceBuffer,
                    renderEncoder: renderEncoder
                )
            }
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
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

    private func prepareBatches(game: Game) {
        batchInstances.removeAll(keepingCapacity: true)
        preparedBatches.removeAll(keepingCapacity: true)
        batchInstances.reserveCapacity(game.renderStats.primitiveCount)
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
            }
        }
    }

    private func appendSolidBatch(
        _ sprites: [Sprite],
        blendMode: BlendMode,
        game: Game
    ) {
        let startIndex = batchInstances.count

        for sprite in sprites {
            batchInstances.append(
                BatchInstance(
                    rect: renderRect(
                        for: sprite,
                        game: game,
                        interpolationMode: game.interpolationMode
                    ).uniform,
                    textureRect: TextureRect.full.uniform,
                    color: resolvedColor(for: sprite).uniform
                )
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
            let startIndex = batchInstances.count

            for sprite in sprites {
                batchInstances.append(
                    BatchInstance(
                        rect: renderRect(
                            for: sprite,
                            game: game,
                            interpolationMode: game.interpolationMode
                        ).uniform,
                        textureRect: TextureRect.full.uniform,
                        color: resolvedColor(
                            for: sprite,
                            fallbackColor: .missingTexture
                        ).uniform
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

        for sprite in sprites {
            guard case .sprite(_, let sourceRect) = sprite.material,
                  let textureRect = textureRect(
                    for: sourceRect,
                    textureID: textureID
                  )
            else {
                continue
            }

            batchInstances.append(
                BatchInstance(
                    rect: renderRect(
                        for: sprite,
                        game: game,
                        interpolationMode: game.interpolationMode
                    ).uniform,
                    textureRect: textureRect.uniform,
                    color: resolvedColor(for: sprite).uniform
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
            PreparedBatch(
                material: material,
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

    private func drawBatch(
        _ batch: PreparedBatch,
        instanceBuffer: MTLBuffer,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        var useTexture = batch.material.useTexture

        guard let pipelineState = pipelineStates[batch.blendMode] else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(
            instanceBuffer,
            offset: batch.startIndex * MemoryLayout<BatchInstance>.stride,
            index: 2
        )
        renderEncoder.setFragmentBytes(
            &useTexture,
            length: MemoryLayout<UInt32>.stride,
            index: 0
        )
        renderEncoder.setFragmentTexture(
            batch.material.texture ?? whiteTexture,
            index: 0
        )
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: batch.instanceCount
        )
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

    private func renderRect(
        for rect: Rect,
        game: Game,
        interpolationMode: InterpolationMode
    ) -> RenderRect {
        let position = Vec2(
            x: rect.origin.x - game.camera.origin.x,
            y: rect.origin.y - game.camera.origin.y
        )

        switch interpolationMode {
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

    private func renderRect(
        for sprite: Sprite,
        game: Game,
        interpolationMode: InterpolationMode
    ) -> RenderRect {
        let position = Vec2(
            x: sprite.position.x - game.camera.origin.x,
            y: sprite.position.y - game.camera.origin.y
        )

        switch interpolationMode {
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

    private func textureRect(
        for sourceRect: Rect?,
        textureID: TextureID
    ) -> TextureRect? {
        guard let sourceRect else {
            return .full
        }

        guard let textureSize = spriteTextureSizes[textureID],
              textureSize.x > 0,
              textureSize.y > 0
        else {
            return nil
        }

        return TextureRect(
            x: sourceRect.origin.x / textureSize.x,
            y: sourceRect.origin.y / textureSize.y,
            width: sourceRect.size.x / textureSize.x,
            height: sourceRect.size.y / textureSize.y
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
        pixelFormat: MTLPixelFormat
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
                        blendMode: blendMode
                    )
                )
            }
        )
    }

    private static func makePipelineState(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        blendMode: BlendMode
    ) -> MTLRenderPipelineState {
        do {
            let library = try device.makeLibrary(
                source: metalShaderSource,
                options: nil
            )
            let descriptor = MTLRenderPipelineDescriptor()

            descriptor.vertexFunction = library.makeFunction(
                name: "spriteVertex"
            )
            descriptor.fragmentFunction = library.makeFunction(
                name: "spriteFragment"
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

private struct PreparedBatch {
    let material: RenderMaterial
    let blendMode: BlendMode
    let startIndex: Int
    let instanceCount: Int
}

private struct BatchInstance {
    let rect: SIMD4<Float>
    let textureRect: SIMD4<Float>
    let color: SIMD4<Float>
}

private struct RenderRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var uniform: SIMD4<Float> {
        SIMD4(
            Float(x),
            Float(y),
            Float(width),
            Float(height)
        )
    }
}

private struct TextureRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let full = TextureRect(x: 0, y: 0, width: 1, height: 1)

    var uniform: SIMD4<Float> {
        SIMD4(
            Float(x),
            Float(y),
            Float(width),
            Float(height)
        )
    }
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

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct BatchInstance {
    float4 rect;
    float4 textureRect;
    float4 color;
};

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
"""
