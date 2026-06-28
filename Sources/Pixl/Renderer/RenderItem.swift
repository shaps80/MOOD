import Swift

/// One prepared render item in logical game pixels.
///
/// `RenderItem` is Pixl's shared instance format for sprites, shapes, and
/// future text. Rects are already camera-adjusted and pixel-aligned; colors,
/// texture coordinates, and shape values are already resolved.
///
/// ```swift
/// let item = RenderItem.sprite(
///     rect: rect,
///     textureRect: .full,
///     color: .white
/// )
/// ```
public struct RenderItem: Equatable, Sendable {
    /// Camera-adjusted, pixel-aligned item bounds.
    public var rect: Rect

    /// Normalized texture coordinates. Shape items use `.full`.
    public var textureRect: TextureRect

    /// Sprite color/tint. Shape items use `.clear`.
    public var color: Color

    /// Packed item kind, radius, stroke width, and line cap.
    public var info: Vec4

    /// Packed line start/end values.
    public var line: Vec4

    /// Shape fill color.
    public var fillColor: Color

    /// Shape stroke color.
    public var strokeColor: Color

    /// Packed antialiasing and corner-style flags.
    public var flags: Vec4

    /// Creates a prepared render item.
    public init(
        kind: RenderItemKind,
        rect: Rect,
        textureRect: TextureRect = .full,
        color: Color = .clear,
        radius: Double = 0,
        strokeWidth: Double = 0,
        lineCap: Double = 0,
        line: Vec4 = Vec4(0, 0, 0, 0),
        fillColor: Color = .clear,
        strokeColor: Color = .clear,
        flags: Vec4 = Vec4(0, 0, 0, 0)
    ) {
        self.rect = rect
        self.textureRect = textureRect
        self.color = color
        self.info = Vec4(Double(kind.rawValue), radius, strokeWidth, lineCap)
        self.line = line
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.flags = flags
    }
}

public extension RenderItem {
    /// Creates a sprite item.
    static func sprite(
        rect: Rect,
        textureRect: TextureRect,
        color: Color
    ) -> RenderItem {
        RenderItem(
            kind: .sprite,
            rect: rect,
            textureRect: textureRect,
            color: color
        )
    }

    /// Creates a shape item.
    static func shape(
        kind: RenderItemKind,
        rect: Rect,
        radius: Double,
        strokeWidth: Double,
        lineCap: Double,
        line: Vec4,
        fillColor: Color,
        strokeColor: Color,
        flags: Vec4
    ) -> RenderItem {
        RenderItem(
            kind: kind,
            rect: rect,
            radius: radius,
            strokeWidth: strokeWidth,
            lineCap: lineCap,
            line: line,
            fillColor: fillColor,
            strokeColor: strokeColor,
            flags: flags
        )
    }
}
