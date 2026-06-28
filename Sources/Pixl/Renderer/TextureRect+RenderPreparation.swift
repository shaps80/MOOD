import Swift

public extension TextureRect {
    /// Converts an optional source frame into normalized texture coordinates.
    ///
    /// Missing source rect means draw the full texture. Missing texture size
    /// falls back to full coordinates so missing-texture debug draws can still
    /// use the sprite's source rect for screen size.
    ///
    /// ```swift
    /// let uv = TextureRect.normalized(
    ///     sourceRect: frame,
    ///     textureSize: Vec2(x: 128, y: 128)
    /// )
    /// ```
    static func normalized(
        sourceRect: Rect?,
        textureSize: Vec2?
    ) -> TextureRect {
        guard let sourceRect,
              let textureSize,
              textureSize.x > 0,
              textureSize.y > 0
        else {
            return .full
        }

        return TextureRect(
            x: sourceRect.origin.x / textureSize.x,
            y: sourceRect.origin.y / textureSize.y,
            width: sourceRect.size.x / textureSize.x,
            height: sourceRect.size.y / textureSize.y
        )
    }
}
