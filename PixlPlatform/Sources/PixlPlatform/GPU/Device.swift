import Swift

public protocol Device {
    func makeBuffer(_ descriptor: BufferDescriptor) throws(DeviceError) -> Buffer
    func makeBuffer(
        copying bytes: UnsafeRawBufferPointer,
        usage: BufferUsage
    ) throws(DeviceError) -> Buffer
    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture
    func makeQueue() throws(DeviceError) -> any Queue
}
