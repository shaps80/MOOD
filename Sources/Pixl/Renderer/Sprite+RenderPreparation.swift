import Swift

public extension Sprite {
    /// The unscaled visual size for this sprite.
    ///
    /// Sprite frames use their source rect size. Full-texture sprites use the
    /// platform-provided loaded texture size. Shapes use their explicit size.
    func naturalSize(textureSize: Vec2? = nil) -> Vec2 {
        switch material {
        case .sprite(_, let sourceRect):
            sourceRect?.size ?? textureSize ?? .zero
        case .shape(_, let size):
            size
        }
    }

    /// The final visual size after applying sprite scale.
    func renderedSize(textureSize: Vec2? = nil) -> Vec2 {
        naturalSize(textureSize: textureSize) * scale
    }

    /// The sprite source rect, when this sprite draws a texture frame.
    var sourceRect: Rect? {
        switch material {
        case .sprite(_, let sourceRect):
            sourceRect
        case .shape:
            nil
        }
    }

    /// Applies tint and opacity to the sprite's base render color.
    func resolvedColor(fallbackColor: Color? = nil) -> Color {
        let baseColor = fallbackColor ?? Color.white

        return Color(
            red: baseColor.red * tint.red,
            green: baseColor.green * tint.green,
            blue: baseColor.blue * tint.blue,
            alpha: baseColor.alpha * tint.alpha * opacity
        )
    }
}
