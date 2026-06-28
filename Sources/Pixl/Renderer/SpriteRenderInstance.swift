import Swift

/// One prepared sprite draw in logical game pixels.
///
/// `rect` is already camera-adjusted and pixel-aligned. `textureRect` is
/// normalized UV space. `color` already includes tint, opacity, and any fallback
/// color chosen by Pixl.
public struct SpriteRenderInstance: Equatable, Sendable {
    public var rect: Rect
    public var textureRect: TextureRect
    public var color: Color

    public init(rect: Rect, textureRect: TextureRect, color: Color) {
        self.rect = rect
        self.textureRect = textureRect
        self.color = color
    }
}
