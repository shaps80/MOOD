import Swift

/// One prepared shape draw in logical game pixels.
///
/// The packed values are intentionally API-neutral. WebGL and Metal can upload
/// them directly without repeating shape semantic switches.
public struct ShapeRenderInstance: Equatable, Sendable {
    /// Camera-adjusted, pixel-aligned shape bounds.
    public var rect: Rect

    /// Packed shape kind, radius, stroke width, and line cap.
    public var info: Vec4

    /// Packed line start/end values.
    public var line: Vec4

    /// Fill color after style resolution.
    public var fillColor: Color

    /// Stroke color after style resolution.
    public var strokeColor: Color

    /// Packed antialiasing and corner-style flags.
    public var flags: Vec4

    /// Creates a prepared shape instance.
    public init(
        rect: Rect,
        info: Vec4,
        line: Vec4,
        fillColor: Color,
        strokeColor: Color,
        flags: Vec4
    ) {
        self.rect = rect
        self.info = info
        self.line = line
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.flags = flags
    }
}
