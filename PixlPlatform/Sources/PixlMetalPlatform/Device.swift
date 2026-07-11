import Metal
import PixlPlatform

final class MetalDevice: Device {
    let metalDevice: MTLDevice
    let textures: ResourcePool<MTLTexture>

    init(device: MTLDevice, textureCapacity: UInt32) {
        metalDevice = device
        textures = ResourcePool(capacity: textureCapacity)
    }

    convenience init?(textureCapacity: UInt32) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(device: device, textureCapacity: textureCapacity)
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
