import Swift

public enum DeviceError: Error, Hashable, Sendable {
    case commandQueueCreationFailed
    case resourceCreationFailed(ResourceKind)
    case unsupportedFormat(PixelFormat)
    case unsupportedTextureUsage(TextureUsage)
    case invalidTextureDescriptor(TextureDescriptor)
}
