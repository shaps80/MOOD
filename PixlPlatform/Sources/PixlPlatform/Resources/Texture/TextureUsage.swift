import Swift

/// Roles permitted for a texture allocation.
public struct TextureUsage: OptionSet, Hashable, Sendable {
    /// Raw usage bitmask.
    public let rawValue: UInt32

    /// Creates texture roles from a raw bitmask.
    /// - Parameter rawValue: Bitmask composed from ``TextureUsage`` constants.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// May be sampled by shaders.
    public static let sampled = TextureUsage(rawValue: 1 << 0)
    /// May be attached to a render pass.
    public static let renderAttachment = TextureUsage(rawValue: 1 << 1)
    /// May be used as general shader storage.
    public static let storage = TextureUsage(rawValue: 1 << 2)
    /// May be the source of a GPU copy.
    public static let copySource = TextureUsage(rawValue: 1 << 3)
    /// May be the destination of a GPU copy.
    public static let copyDestination = TextureUsage(rawValue: 1 << 4)
}
