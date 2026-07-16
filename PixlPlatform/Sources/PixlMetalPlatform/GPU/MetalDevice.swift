import Foundation
import Metal
import PixlPlatform

final class MetalDevice: Device {
    let metalDevice: MTLDevice
    private let commandQueue: MTLCommandQueue
    let buffers: ResourcePool<MTLBuffer>
    let pipelines: ResourcePool<MetalRenderPipeline>
    let samplers: ResourcePool<MTLSamplerState>
    let textures: ResourcePool<MTLTexture>
    private let defaultTexture: MTLTexture
    private let defaultSampler: MTLSamplerState
    private let shaderLibrary: any MTLLibrary

    init(
        device: MTLDevice,
        bufferCapacity: UInt32,
        pipelineCapacity: UInt32,
        samplerCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal command queue creation failed")
        }
        guard let shaderLibrary = try? device.makeDefaultLibrary(
            bundle: Bundle.module
        ) else {
            fatalError("Pixl Metal shader library could not be loaded")
        }
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        textureDescriptor.usage = .shaderRead
        textureDescriptor.storageMode = .shared
        guard let defaultTexture = device.makeTexture(
            descriptor: textureDescriptor
        ) else {
            fatalError("Pixl default texture could not be created")
        }
        var white: UInt32 = .max
        defaultTexture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &white,
            bytesPerRow: 4
        )
        guard let defaultSampler = device.makeSamplerState(
            descriptor: SamplerDescriptor().metalDescriptor
        ) else {
            fatalError("Pixl default sampler could not be created")
        }

        metalDevice = device
        self.commandQueue = commandQueue
        self.defaultTexture = defaultTexture
        self.defaultSampler = defaultSampler
        self.shaderLibrary = shaderLibrary
        buffers = ResourcePool(capacity: bufferCapacity)
        pipelines = ResourcePool(capacity: pipelineCapacity)
        samplers = ResourcePool(capacity: samplerCapacity)
        textures = ResourcePool(capacity: textureCapacity)

        logFunctions(in: shaderLibrary)
    }

    convenience init?(
        bufferCapacity: UInt32,
        pipelineCapacity: UInt32,
        samplerCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(
            device: device,
            bufferCapacity: bufferCapacity,
            pipelineCapacity: pipelineCapacity,
            samplerCapacity: samplerCapacity,
            textureCapacity: textureCapacity
        )
    }

    func makeBuffer(_ descriptor: BufferDescriptor) throws(DeviceError) -> Buffer {
        guard let length = Int(exactly: descriptor.size),
              let metalBuffer = metalDevice.makeBuffer(
                  length: length,
                  options: descriptor.memory.metalResourceOptions
              )
        else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        guard let id = buffers.insert(metalBuffer) else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        return Buffer(id: id, descriptor: descriptor)
    }

    func makeBuffer(
        copying bytes: UnsafeRawBufferPointer,
        usage: BufferUsage,
        memory: BufferMemory
    ) throws(DeviceError) -> Buffer {
        let descriptor = BufferDescriptor(
            size: UInt64(bytes.count),
            usage: usage.union(.copyDestination),
            memory: memory
        )

        let metalBuffer: MTLBuffer

        switch memory {
        case .gpuOnly:
            metalBuffer = try makePrivateBuffer(copying: bytes)

        case .cpuVisible, .gpuToCPU:
            guard let baseAddress = bytes.baseAddress,
                  let buffer = metalDevice.makeBuffer(
                      bytes: baseAddress,
                      length: bytes.count,
                      options: memory.metalResourceOptions
                  )
            else {
                throw DeviceError.resourceCreationFailed(.buffer)
            }
            metalBuffer = buffer
        }

        guard let id = buffers.insert(metalBuffer) else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        return Buffer(id: id, descriptor: descriptor)
    }

    private func makePrivateBuffer(
        copying bytes: UnsafeRawBufferPointer
    ) throws(DeviceError) -> MTLBuffer {
        guard let baseAddress = bytes.baseAddress,
              let staging = metalDevice.makeBuffer(
                  bytes: baseAddress,
                  length: bytes.count,
                  options: .storageModeShared
              ),
              let destination = metalDevice.makeBuffer(
                  length: bytes.count,
                  options: .storageModePrivate
              ),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder()
        else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        blit.copy(
            from: staging,
            sourceOffset: 0,
            to: destination,
            destinationOffset: 0,
            size: bytes.count
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }
        return destination
    }

    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) throws(DeviceError) -> RenderPipeline {
        guard let vertexFunction = shaderLibrary.makeFunction(name: descriptor.vertex.name) else {
            throw DeviceError.shaderFunctionNotFound(descriptor.vertex.name)
        }
        guard let fragmentFunction = shaderLibrary.makeFunction(name: descriptor.fragment.name) else {
            throw DeviceError.shaderFunctionNotFound(descriptor.fragment.name)
        }

        let metalDescriptor = MTLRenderPipelineDescriptor()
        metalDescriptor.vertexFunction = vertexFunction
        metalDescriptor.fragmentFunction = fragmentFunction
        metalDescriptor.colorAttachments[0].pixelFormat = descriptor.colorFormat.metalPixelFormat

        let vertexDescriptor = MTLVertexDescriptor()
        var bufferIndex: UInt32 = 0
        while bufferIndex < descriptor.vertexLayout.bufferCount {
            let layout = descriptor.vertexLayout[buffer: bufferIndex]
            guard let metalLayout = vertexDescriptor.layouts[Int(layout.bufferIndex)] else {
                throw DeviceError.invalidRenderPipelineDescriptor
            }
            metalLayout.stride = Int(layout.stride)
            metalLayout.stepFunction = layout.stepMode.metalStepFunction
            bufferIndex += 1
        }

        var attributeIndex: UInt32 = 0
        while attributeIndex < descriptor.vertexLayout.attributeCount {
            let attribute = descriptor.vertexLayout[attribute: attributeIndex]
            guard let metalAttribute = vertexDescriptor.attributes[Int(attribute.location)] else {
                throw DeviceError.invalidRenderPipelineDescriptor
            }
            metalAttribute.format = attribute.format.metalVertexFormat
            metalAttribute.offset = Int(attribute.offset)
            metalAttribute.bufferIndex = Int(attribute.bufferIndex)
            attributeIndex += 1
        }
        metalDescriptor.vertexDescriptor = vertexDescriptor

        do {
            let state = try metalDevice.makeRenderPipelineState(descriptor: metalDescriptor)
            guard let id = pipelines.insert(
                MetalRenderPipeline(
                    state: state,
                    usesDefaultBindings: descriptor.fragment.name
                        == ShaderFunction.fragment.name
                )
            ) else {
                throw DeviceError.resourceCreationFailed(.renderPipeline)
            }
            return RenderPipeline(id: id)
        } catch {
            if let error = error as? DeviceError { throw error }
            throw DeviceError.renderPipelineCreationFailed
        }
    }

    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture {
        let metalDescriptor = descriptor.metalDescriptor

        guard let metalTexture = metalDevice.makeTexture(descriptor: metalDescriptor) else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        guard let id = textures.insert(metalTexture) else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        return Texture(id: id, descriptor: descriptor)
    }

    func makeTexture(
        copying bytes: [UInt8],
        descriptor: TextureDescriptor,
        bytesPerRow: UInt32
    ) throws(DeviceError) -> Texture {
        guard descriptor.sampleCount == 1,
              descriptor.size.depthOrArrayLayers == 1,
              descriptor.format == .rgba8Unorm
                || descriptor.format == .bgra8Unorm,
              let width = UInt32(exactly: descriptor.size.width),
              let height = UInt32(exactly: descriptor.size.height),
              width > 0,
              height > 0,
              !width.multipliedReportingOverflow(by: 4).overflow
        else {
            throw DeviceError.invalidTextureDescriptor(descriptor)
        }

        let minimumBytesPerRow = width * 4
        let requiredByteCount = UInt64(bytesPerRow)
            .multipliedReportingOverflow(by: UInt64(height))
        guard bytesPerRow >= minimumBytesPerRow,
              !requiredByteCount.overflow,
              UInt64(bytes.count) >= requiredByteCount.partialValue
        else {
            throw DeviceError.invalidTextureDescriptor(descriptor)
        }

        let alignedBytesPerRow = (Int(bytesPerRow) + 255) & ~255
        let stagingSize = alignedBytesPerRow
            .multipliedReportingOverflow(by: Int(height))
        guard !stagingSize.overflow else {
            throw DeviceError.invalidTextureDescriptor(descriptor)
        }
        let stagingLength = stagingSize.partialValue
        guard let staging = metalDevice.makeBuffer(
            length: stagingLength,
            options: .storageModeShared
        ) else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        bytes.withUnsafeBytes { source in
            let destination = staging.contents()
            var row = 0
            while row < Int(height) {
                destination
                    .advanced(by: row * alignedBytesPerRow)
                    .copyMemory(
                        from: source.baseAddress!.advanced(
                            by: row * Int(bytesPerRow)
                        ),
                        byteCount: Int(bytesPerRow)
                    )
                row += 1
            }
        }

        let metalDescriptor = descriptor.metalDescriptor
        metalDescriptor.storageMode = .private
        guard let texture = metalDevice.makeTexture(
            descriptor: metalDescriptor
        ),
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let blit = commandBuffer.makeBlitCommandEncoder()
        else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        blit.copy(
            from: staging,
            sourceOffset: 0,
            sourceBytesPerRow: alignedBytesPerRow,
            sourceBytesPerImage: stagingLength,
            sourceSize: MTLSize(
                width: Int(width),
                height: Int(height),
                depth: 1
            ),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed,
              let id = textures.insert(texture)
        else {
            throw DeviceError.resourceCreationFailed(.texture)
        }
        return Texture(id: id, descriptor: descriptor)
    }

    func makeSampler(
        _ descriptor: SamplerDescriptor
    ) throws(DeviceError) -> Sampler {
        guard let state = metalDevice.makeSamplerState(
            descriptor: descriptor.metalDescriptor
        ),
        let id = samplers.insert(state)
        else {
            throw DeviceError.resourceCreationFailed(.sampler)
        }
        return Sampler(id: id, descriptor: descriptor)
    }

    func textureWriter(
        for texture: Texture
    ) -> (any TextureWriter)? {
        var metalTexture: (any MTLTexture)?
        guard textures.withValue(for: texture.id, { value in
            metalTexture = value.pointee
        }) != nil,
        let metalTexture
        else {
            return nil
        }

        return MetalTextureWriter(
            texture: metalTexture,
            queue: commandQueue,
            descriptor: texture.descriptor
        )
    }

    func makeQueue() throws(DeviceError) -> any Queue {
        makeMetalQueue()
    }

    func makeMetalQueue() -> MetalQueue {
        MetalQueue(
            queue: commandQueue,
            buffers: buffers,
            pipelines: pipelines,
            samplers: samplers,
            textures: textures,
            defaultTexture: defaultTexture,
            defaultSampler: defaultSampler
        )
    }

    func destroy(_ buffer: Buffer) {
        let removed = buffers.remove(buffer.id)
        precondition(
            removed,
            "Buffer is invalid or has already been destroyed"
        )
    }

    func destroy(_ pipeline: RenderPipeline) {
        let removed = pipelines.remove(pipeline.id)
        precondition(
            removed,
            "Render pipeline is invalid or has already been destroyed"
        )
    }

    func destroy(_ sampler: Sampler) {
        let removed = samplers.remove(sampler.id)
        precondition(
            removed,
            "Sampler is invalid or has already been destroyed"
        )
    }

    func destroy(_ texture: Texture) {
        let removed = textures.remove(texture.id)
        precondition(
            removed,
            "Texture is invalid or has already been destroyed"
        )
    }

    private func logFunctions(in library: any MTLLibrary) {
        for name in library.functionNames.sorted() {
            print("Registered shader '\(name)'")
        }
    }
}
