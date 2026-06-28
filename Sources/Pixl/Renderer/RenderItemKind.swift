import Swift

/// Shader-facing render item kinds.
///
/// `RenderItemKind` values are uploaded as numeric instance data. Pixl owns
/// the meaning so platform renderers can share one broad item path.
///
/// ```swift
/// let kind = RenderItemKind.sprite
/// ```
public enum RenderItemKind: Int, Equatable, Sendable {
    /// A textured or fallback-color sprite.
    case sprite = 0

    /// An axis-aligned rectangle.
    case rect = 1

    /// A rounded rectangle.
    case roundedRect = 2

    /// An ellipse.
    case ellipse = 3

    /// A stroked line segment.
    case line = 4
}
