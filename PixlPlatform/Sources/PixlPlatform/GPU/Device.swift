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

    func makeTexture(
        copying bytes: [UInt8],
        descriptor: TextureDescriptor,
        bytesPerRow: UInt32
    ) throws(DeviceError) -> Texture

    func textureWriter(
        for texture: Texture
    ) -> (any TextureWriter)?

    func makeSampler(
        _ descriptor: SamplerDescriptor
    ) throws(DeviceError) -> Sampler

    func makeQueue() throws(DeviceError) -> any Queue

    func destroy(_ buffer: Buffer)
    func destroy(_ pipeline: RenderPipeline)
    func destroy(_ sampler: Sampler)
    func destroy(_ texture: Texture)
}

public extension Device {
    func textureWriter(
        for texture: Texture
    ) -> (any TextureWriter)? {
        nil
    }
}
