import Swift

public struct TextureDescriptor: Hashable, Sendable {
    public var size: TextureSize
    public var format: PixelFormat
    public var usage: TextureUsage
    public var sampleCount: Int

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
