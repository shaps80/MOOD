import Swift

public protocol Device {
    var shaders: ShaderRegistry { get }

    func makeBuffer(_ descriptor: BufferDescriptor) throws(DeviceError) -> Buffer
    func makeBuffer(
        copying bytes: UnsafeRawBufferPointer,
        usage: BufferUsage,
        memory: BufferMemory
    ) throws(DeviceError) -> Buffer

    func makeShaderLibrary(_ shader: borrowing Shader) throws(DeviceError) -> any ShaderLibrary
    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) throws(DeviceError) -> RenderPipeline

    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture
    func makeQueue() throws(DeviceError) -> any Queue
}
