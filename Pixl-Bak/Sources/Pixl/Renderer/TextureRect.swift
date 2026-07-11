import Swift

/// Normalized texture coordinates for a sprite draw.
///
/// Values are stored in UV space, where `(0, 0)` is the texture origin and
/// `(1, 1)` is the full texture size.
public struct TextureRect: Equatable, Sendable {
    /// Normalized UV origin.
    public var origin: Vec2

    /// Normalized UV size.
    public var size: Vec2

    /// Creates a texture rect from origin and size vectors.
    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    /// Creates a texture rect from scalar UV values.
    ///
    /// ```swift
    /// let topLeftQuarter = TextureRect(x: 0, y: 0, width: 0.5, height: 0.5)
    /// ```
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
    }

    /// UV coordinates for the whole texture.
    public static let full = TextureRect(x: 0, y: 0, width: 1, height: 1)
}
