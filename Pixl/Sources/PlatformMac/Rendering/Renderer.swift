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
    private let sampledPipelineState: MTLRenderPipelineState
    private let presentPipelineState: MTLRenderPipelineState
    private let quadVertexBuffer: MTLBuffer
    private let textureLoader: MTKTextureLoader
    private let nearestSamplerState: MTLSamplerState
    private let linearSamplerState: MTLSamplerState
    private let whiteTexture: MTLTexture
    private let assetResolver: AssetResolver

    private var spriteTextures: [TextureID: MTLTexture] = [:]
    private var spriteTextureSizes: [TextureID: Vec2] = [:]
    private var itemInstances: [ItemInstance] = []
    private var preparedBatches: [PreparedBatch] = []
    private var renderPlanner = RenderPlanner()
    private var instanceBuffer: MTLBuffer?
    private var instanceBufferCapacity = 0
    private var sceneTexture: MTLTexture?
    private var alternateSceneTexture: MTLTexture?
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
            vertexFunctionName: "itemVertex",
            fragmentFunctionName: "itemFragment"
        )
        self.sampledPipelineState = Renderer.makePipelineState(
            device: device,
            pixelFormat: pixelFormat,
            vertexFunctionName: "itemVertex",
            fragmentFunctionName: "itemFragment",
            blendMode: .replace
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

        let frame = renderPlanner.prepareFrame(
            game: game,
            textureSizes: spriteTextureSizes
        )

        prepareBatches(frame: frame)
        let instanceBuffer = uploadItemInstances()

        var currentSceneTexture = sceneTexture(for: game)
        var nextSceneTexture = alternateSceneTexture(for: game)

        guard var sceneEncoder = makeSceneEncoder(
            commandBuffer: commandBuffer,
            texture: currentSceneTexture,
            game: game,
            loadAction: .clear,
            clearColor: game.clearColor
        ) else {
            return
        }

        for batch in preparedBatches {
            if batch.blendMode.usesSceneSampling {
                sceneEncoder.endEncoding()
                copyScene(
                    from: currentSceneTexture,
                    to: nextSceneTexture,
                    commandBuffer: commandBuffer
                )

                guard let sampledEncoder = makeSceneEncoder(
                    commandBuffer: commandBuffer,
                    texture: nextSceneTexture,
                    game: game,
                    loadAction: .load,
                    clearColor: game.clearColor
                ) else {
                    return
                }

                sceneEncoder = sampledEncoder
                drawSampledBatch(
                    batch,
                    sampledSceneTexture: currentSceneTexture,
                    instanceBuffer: instanceBuffer,
                    renderEncoder: sceneEncoder
                )
                swap(&currentSceneTexture, &nextSceneTexture)
            } else {
                drawBatch(
                    batch,
                    instanceBuffer: instanceBuffer,
                    renderEncoder: sceneEncoder
                )
            }
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
        presentEncoder.setFragmentTexture(currentSceneTexture, index: 0)
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

    private func alternateSceneTexture(for game: Game) -> MTLTexture {
        let size = Vec2(
            x: max(1, game.logicalResolution.x.rounded()),
            y: max(1, game.logicalResolution.y.rounded())
        )

        if let alternateSceneTexture, sceneTextureSize == size {
            return alternateSceneTexture
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.x),
            height: Int(size.y),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Unable to create Metal alternate scene texture")
        }

        alternateSceneTexture = texture

        return texture
    }

    private func makeSceneEncoder(
        commandBuffer: MTLCommandBuffer,
        texture: MTLTexture,
        game: Game,
        loadAction: MTLLoadAction,
        clearColor: Color
    ) -> MTLRenderCommandEncoder? {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: clearColor.red,
            green: clearColor.green,
            blue: clearColor.blue,
            alpha: clearColor.alpha
        )
        descriptor.colorAttachments[0].loadAction = loadAction
        descriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: descriptor
        ) else {
            return nil
        }

        encoder.setViewport(
            MTLViewport(
                originX: 0,
                originY: 0,
                width: game.logicalResolution.x.rounded(),
                height: game.logicalResolution.y.rounded(),
                znear: 0,
                zfar: 1
            )
        )
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentSamplerState(
            samplerState(for: game.interpolationMode),
            index: 0
        )

        var resolution = SIMD2<Float>(
            Float(game.logicalResolution.x),
            Float(game.logicalResolution.y)
        )
        encoder.setVertexBytes(
            &resolution,
            length: MemoryLayout<SIMD2<Float>>.stride,
            index: 1
        )

        return encoder
    }

    private func copyScene(
        from source: MTLTexture,
        to destination: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return
        }

        blitEncoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(
                width: source.width,
                height: source.height,
                depth: 1
            ),
            to: destination,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
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
        itemInstances.removeAll(keepingCapacity: true)
        preparedBatches.removeAll(keepingCapacity: true)
        preparedBatches.reserveCapacity(frame.batches.count)

        for batch in frame.batches {
            switch batch {
            case .items(let textureID, let blendMode, let items):
                appendItemBatch(
                    items,
                    textureID: textureID,
                    blendMode: blendMode
                )
            }
        }
    }

    private func appendItemBatch(
        _ items: [RenderItem],
        textureID: TextureID?,
        blendMode: BlendMode
    ) {
        let material = textureID.flatMap { spriteTextures[$0] }
            .map(RenderMaterial.texture) ?? .color
        let startIndex = itemInstances.count

        for item in items {
            itemInstances.append(
                itemInstance(
                    for: item,
                    useFallbackTextureRect: textureID != nil && material.isColor
                )
            )
        }

        appendPreparedBatch(
            material: material,
            blendMode: blendMode,
            startIndex: startIndex
        )
    }

    private func appendPreparedBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int
    ) {
        let instanceCount = itemInstances.count - startIndex

        guard instanceCount > 0 else { return }

        preparedBatches.append(
            .items(
                material: material,
                blendMode: blendMode,
                startIndex: startIndex,
                instanceCount: instanceCount
            )
        )
    }

    private func uploadItemInstances() -> MTLBuffer? {
        guard !itemInstances.isEmpty else { return nil }

        let length = itemInstances.count * MemoryLayout<ItemInstance>.stride

        if instanceBufferCapacity < length {
            guard let buffer = device.makeBuffer(length: length) else {
                return nil
            }

            instanceBuffer = buffer
            instanceBufferCapacity = length
        }

        guard let instanceBuffer else { return nil }

        itemInstances.withUnsafeBytes { bytes in
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
        instanceBuffer: MTLBuffer?,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        switch batch {
        case .items(let material, let blendMode, let startIndex, let instanceCount):
            guard let instanceBuffer else { return }
            drawItemBatch(
                material: material,
                blendMode: blendMode,
                sampledSceneTexture: nil,
                startIndex: startIndex,
                instanceCount: instanceCount,
                instanceBuffer: instanceBuffer,
                renderEncoder: renderEncoder
            )
        }
    }

    private func drawSampledBatch(
        _ batch: PreparedBatch,
        sampledSceneTexture: MTLTexture,
        instanceBuffer: MTLBuffer?,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        switch batch {
        case .items(let material, let blendMode, let startIndex, let instanceCount):
            guard let instanceBuffer else { return }
            drawItemBatch(
                material: material,
                blendMode: blendMode,
                sampledSceneTexture: sampledSceneTexture,
                startIndex: startIndex,
                instanceCount: instanceCount,
                instanceBuffer: instanceBuffer,
                renderEncoder: renderEncoder
            )
        }
    }

    private func drawItemBatch(
        material: RenderMaterial,
        blendMode: BlendMode,
        sampledSceneTexture: MTLTexture?,
        startIndex: Int,
        instanceCount: Int,
        instanceBuffer: MTLBuffer,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        var useTexture = material.useTexture
        var sampled = sampledSceneTexture == nil ? UInt32(0) : UInt32(1)
        var blendModeValue = UInt32(blendMode.shaderValue)

        guard let pipelineState = sampledSceneTexture == nil
            ? pipelineStates[blendMode]
            : sampledPipelineState
        else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(
            instanceBuffer,
            offset: startIndex * MemoryLayout<ItemInstance>.stride,
            index: 2
        )
        renderEncoder.setFragmentBytes(
            &useTexture,
            length: MemoryLayout<UInt32>.stride,
            index: 0
        )
        renderEncoder.setFragmentBytes(
            &sampled,
            length: MemoryLayout<UInt32>.stride,
            index: 1
        )
        renderEncoder.setFragmentBytes(
            &blendModeValue,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        renderEncoder.setFragmentTexture(
            material.texture ?? whiteTexture,
            index: 0
        )
        renderEncoder.setFragmentTexture(
            sampledSceneTexture ?? whiteTexture,
            index: 1
        )
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: instanceCount
        )
    }

    private func itemInstance(
        for item: RenderItem,
        useFallbackTextureRect: Bool
    ) -> ItemInstance {
        let textureRect = useFallbackTextureRect ? TextureRect.full : item.textureRect

        return ItemInstance(
            transform: item.transform.uniform,
            rotation: item.transform.rotationUniform,
            textureRect: textureRect.uniform,
            color: item.color.uniform,
            // info.x is RenderItemKind. Shaders branch on this packed value.
            info: item.info.uniform,
            line: item.line.uniform,
            fillColor: item.fillColor.uniform,
            strokeColor: item.strokeColor.uniform,
            flags: item.flags.uniform
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
            uniqueKeysWithValues: BlendMode.fixedFunctionModes.map { blendMode in
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
            attachment.isBlendingEnabled = false
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

    var isColor: Bool {
        switch self {
        case .color:
            return true
        case .texture:
            return false
        }
    }
}

private enum PreparedBatch {
    case items(
        material: RenderMaterial,
        blendMode: BlendMode,
        startIndex: Int,
        instanceCount: Int
    )
}

private extension PreparedBatch {
    var blendMode: BlendMode {
        switch self {
        case .items(_, let blendMode, _, _):
            return blendMode
        }
    }
}

private struct ItemInstance {
    let transform: SIMD4<Float>
    let rotation: SIMD4<Float>
    let textureRect: SIMD4<Float>
    let color: SIMD4<Float>
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

private extension Vec4 {
    var uniform: SIMD4<Float> {
        SIMD4(
            Float(x),
            Float(y),
            Float(z),
            Float(w)
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

private extension RenderTransform {
    var uniform: SIMD4<Float> {
        SIMD4(
            Float(center.x),
            Float(center.y),
            Float(size.x),
            Float(size.y)
        )
    }

    var rotationUniform: SIMD4<Float> {
        let components = sincos(rotation)

        return SIMD4(
            Float(components.cos),
            Float(components.sin),
            0,
            0
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

struct ItemVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
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

struct ItemInstance {
    float4 transform;
    float4 rotation;
    float4 textureRect;
    float4 color;
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

vertex ItemVertexOut itemVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2 *positions [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]],
    constant ItemInstance *instances [[buffer(2)]]
) {
    ItemInstance instance = instances[instanceID];
    float2 unitPosition = positions[vertexID];
    float2 localPosition = (unitPosition - float2(0.5)) * instance.transform.zw;
    float2 rotatedPosition = float2(
        (localPosition.x * instance.rotation.x) - (localPosition.y * instance.rotation.y),
        (localPosition.x * instance.rotation.y) + (localPosition.y * instance.rotation.x)
    );
    float2 pixelPosition = instance.transform.xy + rotatedPosition;
    float2 zeroToOne = pixelPosition / resolution;
    float2 clipSpace = (zeroToOne * 2.0) - 1.0;

    ItemVertexOut out;
    out.position = float4(clipSpace * float2(1.0, -1.0), 0.0, 1.0);
    out.texCoord = instance.textureRect.xy + (unitPosition * instance.textureRect.zw);
    out.color = instance.color;
    out.localPosition = unitPosition * instance.transform.zw;
    out.size = instance.transform.zw;
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

float3 multiplyBlend(float3 source, float3 destination) {
    return source * destination;
}

float3 screenBlend(float3 source, float3 destination) {
    return source + destination - (source * destination);
}

float3 overlayBlend(float3 source, float3 destination) {
    float3 low = 2.0 * source * destination;
    float3 high = 1.0 - (2.0 * (1.0 - source) * (1.0 - destination));
    return mix(low, high, step(float3(0.5), destination));
}

float3 colorDodgeBlend(float3 source, float3 destination) {
    return mix(
        min(destination / max(1.0 - source, 0.0001), 1.0),
        float3(1.0),
        step(float3(1.0), source)
    );
}

float3 colorBurnBlend(float3 source, float3 destination) {
    return mix(
        1.0 - min((1.0 - destination) / max(source, 0.0001), 1.0),
        float3(0.0),
        step(source, float3(0.0))
    );
}

float3 softLightBlend(float3 source, float3 destination) {
    float3 d = mix(
        ((16.0 * destination - 12.0) * destination + 4.0) * destination,
        sqrt(destination),
        step(float3(0.25), destination)
    );
    float3 low = destination - ((1.0 - (2.0 * source)) * destination * (1.0 - destination));
    float3 high = destination + (((2.0 * source) - 1.0) * (d - destination));
    return mix(low, high, step(float3(0.5), source));
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

float3 rgbToHSL(float3 color) {
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

    return float3(hue, saturation, luminosity);
}

float3 hslToRGB(float3 hsl) {
    if (hsl.y == 0.0) {
        return float3(hsl.z);
    }

    float q = hsl.z < 0.5
        ? hsl.z * (1.0 + hsl.y)
        : hsl.z + hsl.y - (hsl.z * hsl.y);
    float p = (2.0 * hsl.z) - q;

    return float3(
        hueToRGB(p, q, hsl.x + (1.0 / 3.0)),
        hueToRGB(p, q, hsl.x),
        hueToRGB(p, q, hsl.x - (1.0 / 3.0))
    );
}

float3 hslBlend(float3 source, float3 destination, uint mode) {
    float3 sourceHSL = rgbToHSL(source);
    float3 destinationHSL = rgbToHSL(destination);

    if (mode == 14) {
        return hslToRGB(float3(sourceHSL.x, destinationHSL.y, destinationHSL.z));
    }
    if (mode == 15) {
        return hslToRGB(float3(destinationHSL.x, sourceHSL.y, destinationHSL.z));
    }
    if (mode == 16) {
        return hslToRGB(float3(sourceHSL.x, sourceHSL.y, destinationHSL.z));
    }
    return hslToRGB(float3(destinationHSL.x, destinationHSL.y, sourceHSL.z));
}

float3 blendColor(uint mode, float3 source, float3 destination) {
    if (mode == 2) {
        return multiplyBlend(source, destination);
    }
    if (mode == 3) {
        return screenBlend(source, destination);
    }
    if (mode == 5) {
        return overlayBlend(source, destination);
    }
    if (mode == 6) {
        return min(source, destination);
    }
    if (mode == 7) {
        return max(source, destination);
    }
    if (mode == 8) {
        return colorDodgeBlend(source, destination);
    }
    if (mode == 9) {
        return colorBurnBlend(source, destination);
    }
    if (mode == 10) {
        return softLightBlend(source, destination);
    }
    if (mode == 11) {
        return overlayBlend(destination, source);
    }
    if (mode == 12) {
        return abs(destination - source);
    }
    if (mode == 13) {
        return destination + source - (2.0 * destination * source);
    }
    if (mode >= 14 && mode <= 17) {
        return hslBlend(source, destination, mode);
    }
    return source;
}

float4 compositeSource(float4 source, float4 destination, uint mode) {
    if (mode == 4) {
        return source;
    }
    if (mode == 1) {
        return source + destination;
    }

    float3 sourceColor = source.a > 0.0 ? source.rgb / source.a : float3(0.0);
    float3 destinationColor = destination.a > 0.0 ? destination.rgb / destination.a : float3(0.0);
    float3 blendedColor = clamp(blendColor(mode, sourceColor, destinationColor), 0.0, 1.0);
    float alpha = source.a + (destination.a * (1.0 - source.a));
    float3 rgb = (blendedColor * source.a) + (destination.rgb * (1.0 - source.a));

    return float4(rgb, alpha);
}

float4 shapeSourceColor(ItemVertexOut in) {
    float kind = in.info.x;
    float radius = in.info.y;
    float strokeWidth = in.info.z;
    float cap = in.info.w;
    float cornerStyle = in.flags.z;
    float d = 0.0;

    if (kind < 1.5) {
        d = roundedBoxDistance(in.localPosition, in.size, 0.0);
    } else if (kind < 2.5) {
        float circular = roundedBoxDistance(in.localPosition, in.size, radius);
        float continuousDistance = continuousRoundedBoxDistance(in.localPosition, in.size, radius);
        d = mix(circular, continuousDistance, cornerStyle);
    } else if (kind < 3.5) {
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

    if (kind > 3.5) {
        fillCoverage = 0.0;
        strokeCoverage = coverage(d, in.flags.y) * in.strokeColor.a;
    }

    float4 fill = float4(in.fillColor.rgb * fillCoverage, fillCoverage);
    float4 stroke = float4(in.strokeColor.rgb * strokeCoverage, strokeCoverage);
    float4 color = stroke + (fill * (1.0 - stroke.a));
    return color;
}

fragment float4 itemFragment(
    ItemVertexOut in [[stage_in]],
    constant uint &useTexture [[buffer(0)]],
    constant uint &sampled [[buffer(1)]],
    constant uint &blendMode [[buffer(2)]],
    texture2d<float> spriteTexture [[texture(0)]],
    texture2d<float> sampledSceneTexture [[texture(1)]],
    sampler spriteSampler [[sampler(0)]]
) {
    float4 source;

    // info.x is RenderItemKind. 0 is sprite; shape kinds start at 1.
    if (in.info.x < 0.5) {
        source = useTexture != 0
            ? spriteTexture.sample(spriteSampler, in.texCoord)
            : float4(1.0);
        source *= in.color;
        source.rgb *= source.a;
    } else {
        source = shapeSourceColor(in);
    }

    if (sampled == 0) {
        return source;
    }

    float2 destinationSize = float2(sampledSceneTexture.get_width(), sampledSceneTexture.get_height());
    float2 destinationCoord = in.position.xy / destinationSize;
    float4 destination = sampledSceneTexture.sample(spriteSampler, destinationCoord);

    return compositeSource(source, destination, blendMode);
}
"""
