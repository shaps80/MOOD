import Swift

/// One prepared shape draw in logical game pixels.
///
/// The packed values are intentionally API-neutral. WebGL and Metal can upload
/// them directly without repeating shape semantic switches.
public struct ShapeRenderInstance: Equatable, Sendable {
    public var rect: Rect
    public var info: Vec4
    public var line: Vec4
    public var fillColor: Color
    public var strokeColor: Color
    public var flags: Vec4

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
