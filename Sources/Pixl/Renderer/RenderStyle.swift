import Swift

public struct RenderStyle: Equatable, Sendable {
    public var fill: Color?
    public var stroke: Color?
    public var fillStyle: FillStyle
    public var strokeStyle: StrokeStyle?
    public var blendMode: BlendMode
    public var opacity: Double
    public var tint: Color

    public init(
        fill: Color? = .white,
        stroke: Color? = nil,
        fillStyle: FillStyle = FillStyle(),
        strokeStyle: StrokeStyle? = nil,
        blendMode: BlendMode = .normal,
        opacity: Double = 1,
        tint: Color = .white
    ) {
        self.fill = fill
        self.stroke = stroke
        self.fillStyle = fillStyle
        self.strokeStyle = strokeStyle
        self.blendMode = blendMode
        self.opacity = opacity
        self.tint = tint
    }
}
