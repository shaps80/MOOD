@preconcurrency import Metal
@preconcurrency import MetalKit
import GameCore
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
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            return
        }

        let viewport = GameViewport(
            drawableSize: view.drawableSize,
            gameSize: game.logicalResolution,
            interpolationMode: game.interpolationMode
        )

        renderEncoder.setViewport(viewport.metalViewport)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(
            samplerState(for: game.interpolationMode),
            index: 0
        )

        drawRect(
            RenderRect(
                x: 0,
                y: 0,
                width: game.logicalResolution.x,
                height: game.logicalResolution.y
            ),
            material: .color(game.clearColor),
            game: game,
            renderEncoder: renderEncoder
        )

        for sprite in game.sprites {
            drawSprite(sprite, game: game, renderEncoder: renderEncoder)
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

    private func drawSprite(
        _ sprite: Sprite,
        game: Game,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        switch sprite.material {
        case .color(let color):
            drawRect(
                renderRect(
                    for: sprite,
                    game: game,
                    interpolationMode: game.interpolationMode
                ),
                material: .color(color),
                game: game,
                renderEncoder: renderEncoder
            )
        case .sprite(let textureID, let sourceRect):
            guard let texture = spriteTextures[textureID],
                  let textureRect = textureRect(
                    for: sourceRect,
                    textureID: textureID
                  )
            else {
                drawRect(
                    renderRect(
                        for: sprite,
                        game: game,
                        interpolationMode: game.interpolationMode
                    ),
                    material: .color(.missingTexture),
                    game: game,
                    renderEncoder: renderEncoder
                )
                return
            }

            drawRect(
                renderRect(
                    for: sprite,
                    game: game,
                    interpolationMode: game.interpolationMode
                ),
                material: .texture(texture, textureRect),
                game: game,
                renderEncoder: renderEncoder
            )
        }
    }

    private func drawRect(
        _ rect: RenderRect,
        material: RenderMaterial,
        game: Game,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        var resolution = SIMD2<Float>(
            Float(game.logicalResolution.x),
            Float(game.logicalResolution.y)
        )
        var rectUniform = SIMD4<Float>(
            Float(rect.x),
            Float(rect.y),
            Float(rect.width),
            Float(rect.height)
        )
        var textureRectUniform = material.textureRectUniform
        var colorUniform = material.colorUniform
        var useTexture = material.useTexture

        renderEncoder.setVertexBytes(
            &resolution,
            length: MemoryLayout<SIMD2<Float>>.stride,
            index: 1
        )
        renderEncoder.setVertexBytes(
            &rectUniform,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 2
        )
        renderEncoder.setVertexBytes(
            &textureRectUniform,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 3
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
            material.texture ?? whiteTexture,
            index: 0
        )
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6
        )
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
    case texture(MTLTexture, TextureRect)

    var texture: MTLTexture? {
        switch self {
        case .color:
            return nil
        case .texture(let texture, _):
            return texture
        }
    }

    var textureRectUniform: SIMD4<Float> {
        switch self {
        case .color:
            return SIMD4(0, 0, 1, 1)
        case .texture(_, let textureRect):
            return SIMD4(
                Float(textureRect.x),
                Float(textureRect.y),
                Float(textureRect.width),
                Float(textureRect.height)
            )
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

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut spriteVertex(
    uint vertexID [[vertex_id]],
    constant float2 *positions [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]],
    constant float4 &rect [[buffer(2)]],
    constant float4 &textureRect [[buffer(3)]]
) {
    float2 unitPosition = positions[vertexID];
    float2 pixelPosition = rect.xy + (unitPosition * rect.zw);
    float2 zeroToOne = pixelPosition / resolution;
    float2 clipSpace = (zeroToOne * 2.0) - 1.0;

    VertexOut out;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.texCoord = textureRect.xy + (unitPosition * textureRect.zw);
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
