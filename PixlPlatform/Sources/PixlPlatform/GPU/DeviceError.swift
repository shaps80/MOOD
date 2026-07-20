import Swift

/// A GPU device resource-creation failure.
public enum DeviceError: Error, Hashable, Sendable {
    /// A native command queue could not be created.
    case commandQueueCreationFailed
    /// A native resource could not be created.
    case resourceCreationFailed(ResourceKind)
    /// A buffer description is inconsistent or unsupported.
    case invalidBufferDescriptor(BufferDescriptor)
    /// The backend does not support a pixel format.
    case unsupportedFormat(PixelFormat)
    /// The backend does not support the requested texture-usage combination.
    case unsupportedTextureUsage(TextureUsage)
    /// A texture description is inconsistent or invalid.
    case invalidTextureDescriptor(TextureDescriptor)
    /// A render-pipeline description is inconsistent or invalid.
    case invalidRenderPipelineDescriptor
    /// No shader entry point exists with the requested name.
    case shaderFunctionNotFound(String)
    /// Native render-pipeline creation failed.
    case renderPipelineCreationFailed
}
