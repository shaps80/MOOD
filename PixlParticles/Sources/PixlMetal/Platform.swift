import Dispatch
import MetalKit
import PixlRenderer
import QuartzCore

public final class Platform: PixlRenderer.Platform {
    private static let drawableCount = 3
    private static let inFlightFrameCount = 2

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let library: any MTLLibrary
    private let available = DispatchSemaphore(value: inFlightFrameCount)
    private let layer: CAMetalLayer
    private var depthTexture: (any MTLTexture)?

    public convenience init(layer: CAMetalLayer) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.device
        }
        try self.init(device: device, layer: layer)
    }

    public init(device: any MTLDevice, layer: CAMetalLayer) throws {
        guard let queue = device.makeCommandQueue() else {
            throw RenderError.commandQueue
        }
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            throw RenderError.shaderLibrary
        }
        queue.label = "Pixl Metal"
        self.device = device
        self.queue = queue
        self.library = library
        self.layer = layer
    }

    @MainActor
    public static func configure(_ view: MTKView) -> CAMetalLayer {
        let device = MTLCreateSystemDefaultDevice()
        view.device = device
        view.colorPixelFormat = .rgba16Float
        view.depthStencilPixelFormat = .invalid
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
        let layer = view.layer as! CAMetalLayer
        layer.maximumDrawableCount = Self.drawableCount
        return layer
    }

    public func acquireFrame() { available.wait() }
    public func releaseFrame() { available.signal() }

    public func submit(_ commandBuffer: any PixlRenderer.CommandBuffer) {
        guard let commandBuffer = commandBuffer as? MetalCommandBuffer else {
            preconditionFailure("Command buffer belongs to another platform")
        }
        commandBuffer.value.addCompletedHandler { [available] _ in
            available.signal()
        }
        commandBuffer.value.commit()
    }

    public func makeBuffer(
        length: Int,
        memory: BufferMemory
    ) -> (any PixlRenderer.Buffer)? {
        let options: MTLResourceOptions = switch memory {
        case .cpuVisible: .storageModeShared
        case .gpuOnly: .storageModePrivate
        }
        return device.makeBuffer(length: length, options: options).map(MetalBuffer.init)
    }

    public func makeComputePipeline(
        function: String
    ) -> (any PixlRenderer.ComputePipeline)? {
        guard let function = library.makeFunction(name: function),
              let state = try? device.makeComputePipelineState(function: function)
        else { return nil }
        return MetalComputePipeline(state)
    }

    public func makeRenderPipeline(
        _ source: PixlRenderer.RenderPipelineDescriptor
    ) -> (any PixlRenderer.RenderPipeline)? {
        guard let vertex = library.makeFunction(name: source.vertexFunction),
              let fragment = library.makeFunction(name: source.fragmentFunction)
        else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = source.colorFormat.metal
        descriptor.depthAttachmentPixelFormat = source.depthFormat.metal
        switch source.blendMode {
        case .premultiplied:
            let attachment = descriptor.colorAttachments[0]!
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        guard let state = try? device.makeRenderPipelineState(descriptor: descriptor)
        else { return nil }
        return MetalRenderPipeline(state)
    }

    public func makeDepthState(
        compare: PixlRenderer.CompareFunction,
        isWriteEnabled: Bool
    ) -> (any PixlRenderer.DepthState)? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = compare.metal
        descriptor.isDepthWriteEnabled = isWriteEnabled
        return device.makeDepthStencilState(descriptor: descriptor).map(MetalDepthState.init)
    }

    public func makeCommandBuffer() -> (any PixlRenderer.CommandBuffer)? {
        queue.makeCommandBuffer().map(MetalCommandBuffer.init)
    }

    public func currentRenderTarget() -> (any PixlRenderer.RenderTarget)? {
        guard let drawable = layer.nextDrawable() else { return nil }
        let texture = drawable.texture
        let depth = depthTexture(
            width: texture.width,
            height: texture.height
        )
        let descriptor = MTLRenderPassDescriptor()
        let color = descriptor.colorAttachments[0]!
        color.texture = texture
        color.loadAction = .clear
        color.storeAction = .store
        color.clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
        descriptor.depthAttachment.texture = depth
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.depthAttachment.clearDepth = 1
        return MetalRenderTarget(descriptor: descriptor, drawable: drawable)
    }

    private func depthTexture(width: Int, height: Int) -> any MTLTexture {
        if let depthTexture,
           depthTexture.width == width,
           depthTexture.height == height {
            return depthTexture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .memoryless
        descriptor.usage = .renderTarget
        let texture = device.makeTexture(descriptor: descriptor)!
        texture.label = "Pixl Depth"
        depthTexture = texture
        return texture
    }
}

private extension PixlRenderer.PixelFormat {
    var metal: MTLPixelFormat {
        switch self {
        case .rgba16Float: .rgba16Float
        case .depth32Float: .depth32Float
        }
    }
}

private extension PixlRenderer.CompareFunction {
    var metal: MTLCompareFunction {
        switch self {
        case .less: .less
        }
    }
}
