import Dispatch
import Foundation
import Metal
import PixlPlatform

final class MetalDevice: Device {
    let metalDevice: MTLDevice
    let buffers: ResourcePool<MTLBuffer>
    let pipelines: ResourcePool<MetalRenderPipeline>
    let textures: ResourcePool<MTLTexture>
    lazy var shaders = ShaderRegistry(device: self)

    init(
        device: MTLDevice,
        bufferCapacity: UInt32,
        pipelineCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        metalDevice = device
        buffers = ResourcePool(capacity: bufferCapacity)
        pipelines = ResourcePool(capacity: pipelineCapacity)
        textures = ResourcePool(capacity: textureCapacity)
    }

    convenience init?(
        bufferCapacity: UInt32,
        pipelineCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(
            device: device,
            bufferCapacity: bufferCapacity,
            pipelineCapacity: pipelineCapacity,
            textureCapacity: textureCapacity
        )
    }

    func makeBuffer(_ descriptor: BufferDescriptor) throws(DeviceError) -> Buffer {
        guard let length = Int(exactly: descriptor.size),
              let metalBuffer = metalDevice.makeBuffer(
                  length: length,
                  options: .storageModeShared
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
        usage: BufferUsage
    ) throws(DeviceError) -> Buffer {
        let descriptor = BufferDescriptor(
            size: UInt64(bytes.count),
            usage: usage
        )

        guard let baseAddress = bytes.baseAddress,
              let metalBuffer = metalDevice.makeBuffer(
                  bytes: baseAddress,
                  length: bytes.count,
                  options: .storageModeShared
              )
        else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        guard let id = buffers.insert(metalBuffer) else {
            throw DeviceError.resourceCreationFailed(.buffer)
        }

        return Buffer(id: id, descriptor: descriptor)
    }

    func makeShaderLibrary(_ shader: borrowing Shader) throws(DeviceError) -> any ShaderLibrary {
        let library: MTLLibrary

        do {
            library = try shader.withUnsafeBytes {
                try metalDevice.makeLibrary(data: DispatchData(bytes: $0))
            }
        } catch {
            throw DeviceError.resourceCreationFailed(.shader)
        }

        print("PixlMetalPlatform loaded shader functions: \(library.functionNames)")
        return MetalShaderLibrary(library: library)
    }

    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) throws(DeviceError) -> RenderPipeline {
        guard let vertexLibrary = shaders.library(for: descriptor.vertex.shader) as? MetalShaderLibrary,
              let fragmentLibrary = shaders.library(for: descriptor.fragment.shader) as? MetalShaderLibrary
        else {
            throw DeviceError.invalidRenderPipelineDescriptor
        }

        guard let vertexFunction = vertexLibrary.library.makeFunction(name: descriptor.vertex.name) else {
            throw DeviceError.shaderFunctionNotFound(descriptor.vertex.name)
        }
        guard let fragmentFunction = fragmentLibrary.library.makeFunction(name: descriptor.fragment.name) else {
            throw DeviceError.shaderFunctionNotFound(descriptor.fragment.name)
        }

        let metalDescriptor = MTLRenderPipelineDescriptor()
        metalDescriptor.vertexFunction = vertexFunction
        metalDescriptor.fragmentFunction = fragmentFunction
        metalDescriptor.colorAttachments[0].pixelFormat = descriptor.colorFormat.metalPixelFormat
        metalDescriptor.inputPrimitiveTopology = descriptor.topology.metalPrimitiveTopology

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
                    topology: descriptor.topology.metalPrimitiveType
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

    func makeQueue() throws(DeviceError) -> any Queue {
        guard let queue = metalDevice.makeCommandQueue() else {
            throw DeviceError.commandQueueCreationFailed
        }

        return MetalQueue(
            queue: queue,
            buffers: buffers,
            pipelines: pipelines,
            textures: textures
        )
    }
}
