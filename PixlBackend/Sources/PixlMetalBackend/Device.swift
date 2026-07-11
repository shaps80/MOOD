import Metal
import PixlBackend

public final class MetalDevice: Device {
    private let device: MTLDevice
    private let textures: ResourcePool<MTLTexture>

    public init(device: MTLDevice, textureCapacity: UInt32) {
        self.device = device
        textures = ResourcePool(capacity: textureCapacity)
    }

    public convenience init?(textureCapacity: UInt32) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(device: device, textureCapacity: textureCapacity)
    }

    public func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture {
        let metalDescriptor = descriptor.metalDescriptor

        guard let metalTexture = device.makeTexture(descriptor: metalDescriptor) else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        guard let id = textures.insert(metalTexture) else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        return Texture(id: id, descriptor: descriptor)
    }
}
