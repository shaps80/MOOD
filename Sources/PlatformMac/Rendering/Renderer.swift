@preconcurrency import Metal
@preconcurrency import MetalKit
import Pixl
import simd
import Swift

@MainActor
final class Renderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
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
        self.pipelineState = Renderer.makePipelineState(
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
        renderEncoder.setRenderPipelineState(pipelineState)
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
            case .rects(let color, let rects):
                appendRectBatch(rects, color: color, game: game)
            case .sprites(let textureID, let sprites):
                appendSpriteBatch(sprites, textureID: textureID, game: game)
            }
        }
    }

    private func appendRectBatch(
        _ rects: [Rect],
        color: Color,
        game: Game
    ) {
        let startIndex = batchInstances.count

        for rect in rects {
            batchInstances.append(
                BatchInstance(
                    rect: renderRect(
                        for: rect,
                        game: game,
                        interpolationMode: game.interpolationMode
                    ).uniform,
                    textureRect: TextureRect.full.uniform
                )
            )
        }

        appendPreparedBatch(
            material: .color(color),
            startIndex: startIndex
        )
    }

    private func appendSpriteBatch(
        _ sprites: [Sprite],
        textureID: TextureID,
        game: Game
    ) {
        guard let texture = spriteTextures[textureID] else {
            appendRectBatch(
                sprites.map { Rect(origin: $0.position, size: $0.size) },
                color: .missingTexture,
                game: game
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
                    textureRect: textureRect.uniform
                )
            )
        }

        appendPreparedBatch(
            material: .texture(texture),
            startIndex: startIndex
        )
    }

    private func appendPreparedBatch(
        material: RenderMaterial,
        startIndex: Int
    ) {
        let instanceCount = batchInstances.count - startIndex

        guard instanceCount > 0 else { return }

        preparedBatches.append(
            PreparedBatch(
                material: material,
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
        var colorUniform = batch.material.colorUniform
        var useTexture = batch.material.useTexture

        renderEncoder.setVertexBuffer(
            instanceBuffer,
            offset: batch.startIndex * MemoryLayout<BatchInstance>.stride,
            index: 2
        )
        renderEncoder.setFragmentBytes(
            &colorUniform,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0
        )
        renderEncoder.setFragmentBytes(
            &useTexture,
            length: MemoryLayout<UInt32>.stride,
            index: 1
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

    private static func makePipelineState(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat
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
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Unable to create Metal sprite pipeline: \(error)")
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
    case color(Color)
    case texture(MTLTexture)

    var texture: MTLTexture? {
        switch self {
        case .color:
            return nil
        case .texture(let texture):
            return texture
        }
    }

    var colorUniform: SIMD4<Float> {
        switch self {
        case .color(let color):
            return SIMD4(
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        case .texture:
            return SIMD4(1, 1, 1, 1)
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
    let startIndex: Int
    let instanceCount: Int
}

private struct BatchInstance {
    let rect: SIMD4<Float>
    let textureRect: SIMD4<Float>
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

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct BatchInstance {
    float4 rect;
    float4 textureRect;
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
    return out;
}

fragment float4 spriteFragment(
    VertexOut in [[stage_in]],
    constant float4 &color [[buffer(0)]],
    constant uint &useTexture [[buffer(1)]],
    texture2d<float> spriteTexture [[texture(0)]],
    sampler spriteSampler [[sampler(0)]]
) {
    if (useTexture != 0) {
        return spriteTexture.sample(spriteSampler, in.texCoord);
    }

    return color;
}
"""
