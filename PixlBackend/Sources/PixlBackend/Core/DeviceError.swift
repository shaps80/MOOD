import Swift

public enum DeviceError: Error, Hashable, Sendable {
    case resourceCreationFailed(ResourceKind)
    case unsupportedFormat(PixelFormat)
    case unsupportedTextureUsage(TextureUsage)
    case invalidTextureDescriptor(TextureDescriptor)
}
