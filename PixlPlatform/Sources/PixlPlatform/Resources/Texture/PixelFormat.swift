import Swift

/// Portable texture texel representations.
public enum PixelFormat: Hashable, Sendable {
    /// Four normalized 8-bit channels ordered red, green, blue, alpha.
    case rgba8Unorm
    /// Four normalized 8-bit channels ordered blue, green, red, alpha.
    case bgra8Unorm
    /// One 32-bit floating-point depth component.
    case depth32Float
}
