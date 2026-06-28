import Swift

/// One prepared sprite draw in logical game pixels.
///
/// `rect` is already camera-adjusted and pixel-aligned. `textureRect` is
/// normalized UV space. `color` already includes tint, opacity, and any fallback
/// color chosen by Pixl.
public struct SpriteRenderInstance: Equatable, Sendable {
    /// Camera-adjusted, pixel-aligned sprite bounds.
    public var rect: Rect

    /// Normalized UV coordinates.
    public var textureRect: TextureRect

    /// Final draw color.
    public var color: Color

    /// Creates a prepared sprite instance.
    public init(rect: Rect, textureRect: TextureRect, color: Color) {
        self.rect = rect
        self.textureRect = textureRect
        self.color = color
    }
}
