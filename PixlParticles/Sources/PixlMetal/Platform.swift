import Dispatch
import MetalKit
import PixlRenderer
import QuartzCore

@MainActor
public final class Platform: PixlRenderer.Platform {
    private static let frameCount = 2

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let library: any MTLLibrary
    private let available = DispatchSemaphore(value: frameCount)
    private weak var view: MTKView?

    public convenience init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.device
        }
        try self.init(device: device)
    }

    public init(device: any MTLDevice) throws {
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
    }

    public func configure(_ view: MTKView) {
        self.view = view
        view.device = device
        (view.layer as? CAMetalLayer)?.maximumDrawableCount = Self.frameCount
        view.colorPixelFormat = .rgba16Float
        view.depthStencilStorageMode = .memoryless
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
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
        guard let descriptor = view?.currentRenderPassDescriptor,
              let drawable = view?.currentDrawable
        else { return nil }
        return MetalRenderTarget(descriptor: descriptor, drawable: drawable)
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
