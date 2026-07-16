import Swift

public protocol Device {
    func makeBuffer(
        _ descriptor: BufferDescriptor
    ) throws(DeviceError) -> Buffer

    func makeBuffer(
        copying bytes: UnsafeRawBufferPointer,
        usage: BufferUsage,
        memory: BufferMemory
    ) throws(DeviceError) -> Buffer

    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) throws(DeviceError) -> RenderPipeline

    func makeTexture(
        _ descriptor: TextureDescriptor
    ) throws(DeviceError) -> Texture

    func makeQueue() throws(DeviceError) -> any Queue

    func destroy(_ buffer: Buffer)
    func destroy(_ pipeline: RenderPipeline)
    func destroy(_ texture: Texture)
}
