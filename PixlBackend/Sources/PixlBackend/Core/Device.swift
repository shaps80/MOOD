import Swift

public protocol Device {
    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture
    func makeQueue() throws(DeviceError) -> any Queue
}
