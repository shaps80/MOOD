import Dispatch
import MetalKit
import PixlParticles
import PixlRenderer
import QuartzCore
import simd

@MainActor
public final class Renderer {
    private static let bufferCount = 2
    private static let cullingThreadCount = 256

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let classifyPipeline: any MTLComputePipelineState
    private let scanPipeline: any MTLComputePipelineState
    private let scatterPipeline: any MTLComputePipelineState
    private let depthState: any MTLDepthStencilState
    private let lowerer = PixlRenderer.Renderer()
    private let available = DispatchSemaphore(value: bufferCount)

    private var buffers: [any MTLBuffer] = []
    private var capacity = 0
    private var stateBufferIndex = -1
    private var stateSystem: ObjectIdentifier?
    private var stateTick: UInt64?
    private var cullingBuffers: [CullingBuffers] = []
    private var cullingBufferIndex = 0

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
        queue.label = "Pixl Particles"
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            throw RenderError.shaderLibrary
        }
        guard
            let vertex = library.makeFunction(name: "pointVertex"),
            let fragment = library.makeFunction(name: "pointFragment"),
            let classify = library.makeFunction(
                name: "classifyAndScanVisibility"
            ),
            let scan = library.makeFunction(name: "scanVisibilityBlocks"),
            let scatter = library.makeFunction(name: "scatterVisibleIndices")
        else {
            throw RenderError.shaderFunction
        }

        guard
            let classifyPipeline = try? device.makeComputePipelineState(
                function: classify
            ),
            let scanPipeline = try? device.makeComputePipelineState(
                function: scan
            ),
            let scatterPipeline = try? device.makeComputePipelineState(
                function: scatter
            )
        else {
            throw RenderError.pipeline
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
        self.classifyPipeline = classifyPipeline
        self.scanPipeline = scanPipeline
        self.scatterPipeline = scatterPipeline
        self.depthState = depthState
    }

    public func configure(_ view: MTKView) {
        view.device = device
        (view.layer as? CAMetalLayer)?.maximumDrawableCount = Self.bufferCount
        view.colorPixelFormat = .rgba16Float
        view.depthStencilStorageMode = .memoryless
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
        let cullingBuffers = cullingBuffers[cullingBufferIndex]
        cullingBufferIndex = (cullingBufferIndex + 1) % Self.bufferCount

        guard
            let commandBuffer = queue.makeCommandBuffer()
        else {
            throw RenderError.commandBuffer
        }
        commandBuffer.label = "Pixl Particles Frame"

        try encodeCulling(
            particleCount: count,
            interpolation: interpolation,
            viewProjection: viewProjection,
            positions: buffer,
            buffers: cullingBuffers,
            commandBuffer: commandBuffer
        )

        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable
        else {
            return
        }

        guard
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            )
        else {
            throw RenderError.commandBuffer
        }
        encoder.label = "Point Draw"

        var viewProjection = viewProjection
        var interpolation = interpolation
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBuffer(
            cullingBuffers.visibleIndices,
            offset: 0,
            index: 1
        )
        encoder.setVertexBytes(
            &viewProjection,
            length: MemoryLayout<simd_float4x4>.stride,
            index: 2
        )
        encoder.setVertexBytes(
            &interpolation,
            length: MemoryLayout<Float>.stride,
            index: 3
        )
        encoder.drawPrimitives(
            type: .point,
            indirectBuffer: cullingBuffers.indirectArguments,
            indirectBufferOffset: 0
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

        for index in 0..<Self.bufferCount {
            guard let buffer = device.makeBuffer(
                length: length,
                options: .storageModeShared
            ) else {
                throw RenderError.buffer
            }
            buffer.label = "Position Pairs \(index)"
            buffers.append(buffer)
        }

        self.buffers = buffers
        let blockCapacity = (
            requiredCapacity + Self.cullingThreadCount - 1
        ) / Self.cullingThreadCount
        var cullingBuffers: [CullingBuffers] = []
        cullingBuffers.reserveCapacity(Self.bufferCount)
        for index in 0..<Self.bufferCount {
            guard
                let localOffsets = device.makeBuffer(
                    length: requiredCapacity * MemoryLayout<UInt32>.stride,
                    options: .storageModePrivate
                ),
                let blockSums = device.makeBuffer(
                    length: blockCapacity * MemoryLayout<UInt32>.stride,
                    options: .storageModePrivate
                ),
                let blockOffsets = device.makeBuffer(
                    length: blockCapacity * MemoryLayout<UInt32>.stride,
                    options: .storageModePrivate
                ),
                let visibleIndices = device.makeBuffer(
                    length: requiredCapacity * MemoryLayout<UInt32>.stride,
                    options: .storageModePrivate
                ),
                let indirectArguments = device.makeBuffer(
                    length: 4 * MemoryLayout<UInt32>.stride,
                    options: .storageModePrivate
                )
            else {
                throw RenderError.buffer
            }
            localOffsets.label = "Culling Local Offsets \(index)"
            blockSums.label = "Culling Block Sums \(index)"
            blockOffsets.label = "Culling Block Offsets \(index)"
            visibleIndices.label = "Visible Particle Indices \(index)"
            indirectArguments.label = "Point Draw Arguments \(index)"
            cullingBuffers.append(
                CullingBuffers(
                    localOffsets: localOffsets,
                    blockSums: blockSums,
                    blockOffsets: blockOffsets,
                    visibleIndices: visibleIndices,
                    indirectArguments: indirectArguments
                )
            )
        }

        self.cullingBuffers = cullingBuffers
        cullingBufferIndex = 0
        capacity = requiredCapacity
        stateBufferIndex = -1
        stateSystem = nil
        stateTick = nil
    }

    private func encodeCulling(
        particleCount: Int,
        interpolation: Float,
        viewProjection: simd_float4x4,
        positions: any MTLBuffer,
        buffers: CullingBuffers,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        let integerBlockCount = (
            particleCount + Self.cullingThreadCount - 1
        ) / Self.cullingThreadCount
        var particleCount = UInt32(particleCount)
        var blockCount = UInt32(integerBlockCount)
        var interpolation = interpolation
        var viewProjection = viewProjection

        if particleCount > 0 {
            guard let classify = commandBuffer.makeComputeCommandEncoder() else {
                throw RenderError.commandBuffer
            }
            classify.label = "Culling Classify and Local Scan"
            classify.setComputePipelineState(classifyPipeline)
            classify.setBuffer(positions, offset: 0, index: 0)
            classify.setBuffer(buffers.localOffsets, offset: 0, index: 1)
            classify.setBuffer(buffers.blockSums, offset: 0, index: 2)
            classify.setBytes(
                &viewProjection,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 3
            )
            classify.setBytes(
                &interpolation,
                length: MemoryLayout<Float>.stride,
                index: 4
            )
            classify.setBytes(
                &particleCount,
                length: MemoryLayout<UInt32>.stride,
                index: 5
            )
            classify.dispatchThreadgroups(
                MTLSize(width: Int(blockCount), height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(
                    width: Self.cullingThreadCount,
                    height: 1,
                    depth: 1
                )
            )
            classify.endEncoding()
        }

        guard let scan = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandBuffer
        }
        scan.label = "Culling Block Scan"
        scan.setComputePipelineState(scanPipeline)
        scan.setBuffer(buffers.blockSums, offset: 0, index: 0)
        scan.setBuffer(buffers.blockOffsets, offset: 0, index: 1)
        scan.setBuffer(buffers.indirectArguments, offset: 0, index: 2)
        scan.setBytes(
            &blockCount,
            length: MemoryLayout<UInt32>.stride,
            index: 3
        )
        scan.dispatchThreads(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        scan.endEncoding()

        if particleCount > 0 {
            guard let scatter = commandBuffer.makeComputeCommandEncoder() else {
                throw RenderError.commandBuffer
            }
            scatter.label = "Culling Scatter"
            scatter.setComputePipelineState(scatterPipeline)
            scatter.setBuffer(buffers.localOffsets, offset: 0, index: 0)
            scatter.setBuffer(buffers.blockOffsets, offset: 0, index: 1)
            scatter.setBuffer(buffers.visibleIndices, offset: 0, index: 2)
            scatter.setBytes(
                &particleCount,
                length: MemoryLayout<UInt32>.stride,
                index: 3
            )
            scatter.dispatchThreads(
                MTLSize(width: Int(particleCount), height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(
                    width: Self.cullingThreadCount,
                    height: 1,
                    depth: 1
                )
            )
            scatter.endEncoding()
        }
    }
}

private struct CullingBuffers {
    let localOffsets: any MTLBuffer
    let blockSums: any MTLBuffer
    let blockOffsets: any MTLBuffer
    let visibleIndices: any MTLBuffer
    let indirectArguments: any MTLBuffer
}
