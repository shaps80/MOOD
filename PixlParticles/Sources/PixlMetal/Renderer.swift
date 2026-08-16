import Dispatch
import MetalKit
import PixlParticles
import PixlRenderer
import QuartzCore
import simd

@MainActor
public final class Renderer {
    private static let bufferCount = 2

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let depthState: any MTLDepthStencilState
    private let lowerer = PixlRenderer.Renderer()
    private let available = DispatchSemaphore(value: bufferCount)

    private var buffers: [any MTLBuffer] = []
    private var capacity = 0
    private var stateBufferIndex = -1
    private var stateSystem: ObjectIdentifier?
    private var stateTick: UInt64?

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
        guard
            let vertex = library.makeFunction(name: "pointVertex"),
            let fragment = library.makeFunction(name: "pointFragment")
        else {
            throw RenderError.shaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float

        guard let pipeline = try? device.makeRenderPipelineState(
            descriptor: descriptor
        ) else {
            throw RenderError.pipeline
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true

        guard let depthState = device.makeDepthStencilState(
            descriptor: depthDescriptor
        ) else {
            throw RenderError.depthState
        }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.depthState = depthState
    }

    public func configure(_ view: MTKView) {
        view.device = device
        (view.layer as? CAMetalLayer)?.maximumDrawableCount = Self.bufferCount
        view.colorPixelFormat = .rgba16Float
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 1)
    }

    public func render(
        _ system: PixlParticles.System,
        interpolation: Float,
        tick: UInt64,
        viewProjection: simd_float4x4,
        in view: MTKView
    ) throws {
        precondition(interpolation >= 0 && interpolation <= 1)

        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable
        else {
            return
        }

        available.wait()
        var submitted = false
        defer {
            if !submitted {
                available.signal()
            }
        }

        try ensureCapacity(max(system.particleCount, 1))

        let systemID = ObjectIdentifier(system)
        if stateSystem != systemID || stateTick != tick {
            stateBufferIndex = (stateBufferIndex + 1) % Self.bufferCount
            let pointer = buffers[stateBufferIndex].contents().bindMemory(
                to: PositionPair.self,
                capacity: capacity
            )
            let positions = UnsafeMutableBufferPointer(
                start: pointer,
                count: system.particleCount
            )
            _ = lowerer.lowerPositionPairs(from: system, into: positions)
            stateSystem = systemID
            stateTick = tick
        }

        let buffer = buffers[stateBufferIndex]
        let count = system.particleCount

        guard
            let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            )
        else {
            throw RenderError.commandBuffer
        }

        var viewProjection = viewProjection
        var interpolation = interpolation
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(
            &viewProjection,
            length: MemoryLayout<simd_float4x4>.stride,
            index: 1
        )
        encoder.setVertexBytes(
            &interpolation,
            length: MemoryLayout<Float>.stride,
            index: 2
        )
        encoder.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: count
        )
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [available] _ in
            available.signal()
        }
        submitted = true
        commandBuffer.commit()
    }

    private func ensureCapacity(_ requiredCapacity: Int) throws {
        guard requiredCapacity > capacity else { return }

        let length = requiredCapacity * MemoryLayout<PositionPair>.stride
        var buffers: [any MTLBuffer] = []
        buffers.reserveCapacity(Self.bufferCount)

        for _ in 0..<Self.bufferCount {
            guard let buffer = device.makeBuffer(
                length: length,
                options: .storageModeShared
            ) else {
                throw RenderError.buffer
            }
            buffers.append(buffer)
        }

        self.buffers = buffers
        capacity = requiredCapacity
        stateBufferIndex = -1
        stateSystem = nil
        stateTick = nil
    }
}
