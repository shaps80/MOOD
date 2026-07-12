import Dispatch
import Foundation
import Metal
import PixlPlatform

final class MetalDevice: Device {
    let metalDevice: MTLDevice
    let buffers: ResourcePool<MTLBuffer>
    let textures: ResourcePool<MTLTexture>

    init(
        device: MTLDevice,
        bufferCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        metalDevice = device
        buffers = ResourcePool(capacity: bufferCapacity)
        textures = ResourcePool(capacity: textureCapacity)
    }

    convenience init?(
        bufferCapacity: UInt32,
        textureCapacity: UInt32
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(
            device: device,
            bufferCapacity: bufferCapacity,
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

        return MetalQueue(queue: queue, textures: textures)
    }
}
