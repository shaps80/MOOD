import Swift

/// Size, texel format, allowed roles, and sampling count for a texture allocation.
public struct TextureDescriptor: Hashable, Sendable {
    /// Texture extent and layer count.
    public var size: TextureSize
    /// Texel representation.
    public var format: PixelFormat
    /// Roles in which the texture may be used.
    public var usage: TextureUsage
    /// Number of samples stored per pixel.
    public var sampleCount: Int

    /// Creates a texture description.
    /// - Parameters:
    ///   - size: Texture extent and layer count.
    ///   - format: Texel representation.
    ///   - usage: Nonempty set of permitted roles.
    ///   - sampleCount: Positive samples stored per pixel.
    public init(
        size: TextureSize,
        format: PixelFormat,
        usage: TextureUsage,
        sampleCount: Int = 1
    ) {
        self.size = size
        self.format = format
        self.usage = usage
        self.sampleCount = sampleCount
    }
}
