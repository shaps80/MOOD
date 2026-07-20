import Swift

/// Logical GPU access for creating and explicitly destroying portable resources.
public protocol Device {
    /// Creates an uninitialized buffer allocation.
    /// - Parameter descriptor: Complete size, usage, and memory intent.
    /// - Returns: An opaque buffer owned by this device.
    /// - Throws: ``DeviceError`` when the descriptor is invalid or allocation fails.
    func makeBuffer(
        _ descriptor: BufferDescriptor
    ) throws(DeviceError) -> Buffer

    /// Creates a buffer initialized by copying bytes.
    /// - Parameters:
    ///   - bytes: Source bytes copied before this method returns.
    ///   - usage: Roles in which the buffer may be used.
    ///   - memory: Intended CPU/GPU visibility.
    /// - Returns: An opaque initialized buffer owned by this device.
    /// - Throws: ``DeviceError`` when the inputs are invalid or allocation fails.
    func makeBuffer(
        copying bytes: UnsafeRawBufferPointer,
        usage: BufferUsage,
        memory: BufferMemory
    ) throws(DeviceError) -> Buffer

    /// Creates immutable render-pipeline state.
    /// - Parameter descriptor: Shader, vertex-layout, target-format, and blending configuration.
    /// - Returns: An opaque pipeline owned by this device.
    /// - Throws: ``DeviceError`` when shaders are unavailable, configuration is invalid, or creation fails.
    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) throws(DeviceError) -> RenderPipeline

    /// Creates a texture without initial pixel contents.
    /// - Parameter descriptor: Complete texture size, format, usage, and sample count.
    /// - Returns: An opaque texture owned by this device.
    /// - Throws: ``DeviceError`` when the descriptor is invalid or allocation fails.
    func makeTexture(
        _ descriptor: TextureDescriptor
    ) throws(DeviceError) -> Texture

    /// Creates a texture initialized by copying pixel bytes.
    /// - Parameters:
    ///   - bytes: Source pixel bytes copied during creation.
    ///   - descriptor: Complete texture description.
    ///   - bytesPerRow: Source stride between consecutive pixel rows.
    /// - Returns: An opaque initialized texture owned by this device.
    /// - Throws: ``DeviceError`` when inputs are invalid, unsupported, or creation fails.
    func makeTexture(
        copying bytes: [UInt8],
        descriptor: TextureDescriptor,
        bytesPerRow: UInt32
    ) throws(DeviceError) -> Texture

    /// Requests asynchronous replacement access for an existing texture.
    /// - Parameter texture: Live texture created by this device.
    /// - Returns: A writer when supported, otherwise `nil`.
    func textureWriter(
        for texture: Texture
    ) -> (any TextureWriter)?

    /// Creates immutable texture-sampling state.
    /// - Parameter descriptor: Filtering and addressing configuration.
    /// - Returns: An opaque sampler owned by this device.
    /// - Throws: ``DeviceError`` when creation fails.
    func makeSampler(
        _ descriptor: SamplerDescriptor
    ) throws(DeviceError) -> Sampler

    /// Creates a submission queue for recorded frames.
    /// - Returns: A queue associated with this device.
    /// - Throws: ``DeviceError/commandQueueCreationFailed`` when creation fails.
    func makeQueue() throws(DeviceError) -> any Queue

    /// Invalidates and releases a buffer. All copied handles become stale.
    /// - Parameter buffer: Live buffer created by this device.
    func destroy(_ buffer: Buffer)
    /// Invalidates and releases a render pipeline. All copied handles become stale.
    /// - Parameter pipeline: Live pipeline created by this device.
    func destroy(_ pipeline: RenderPipeline)
    /// Invalidates and releases a sampler. All copied handles become stale.
    /// - Parameter sampler: Live sampler created by this device.
    func destroy(_ sampler: Sampler)
    /// Invalidates and releases a texture. All copied handles become stale.
    /// - Parameter texture: Live texture created by this device.
    func destroy(_ texture: Texture)
}

public extension Device {
    /// Returns `nil`; adapters override this when live texture replacement is supported.
    /// - Parameter texture: Texture for which replacement access is requested.
    /// - Returns: Always `nil` in the default implementation.
    func textureWriter(
        for texture: Texture
    ) -> (any TextureWriter)? {
        nil
    }
}
