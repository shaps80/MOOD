import Metal
import PixlBackend

public final class MetalDevice: Device {
    private let device: MTLDevice
    private var nextResourceID: UInt64 = 1
    private var textures: [ResourceID: MTLTexture] = [:]

    public init(device: MTLDevice) {
        self.device = device
    }

    public convenience init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.init(device: device)
    }

    public func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture {
        let metalDescriptor = descriptor.metalDescriptor

        guard let metalTexture = device.makeTexture(descriptor: metalDescriptor) else {
            throw DeviceError.resourceCreationFailed(.texture)
        }

        let id = ResourceID(nextResourceID)
        nextResourceID += 1

        textures[id] = metalTexture
        return Texture(id: id, descriptor: descriptor)
    }
}
