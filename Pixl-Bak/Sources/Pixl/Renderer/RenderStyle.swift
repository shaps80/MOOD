import Swift

/// Styling applied to paths and shapes.
///
/// `RenderStyle` mirrors the small set of drawing options Pixl needs without
/// exposing platform APIs.
///
/// ```swift
/// let style = RenderStyle(
///     fill: .red,
///     stroke: .white,
///     strokeStyle: StrokeStyle(lineWidth: 2)
/// )
/// ```
public struct RenderStyle: Equatable, Sendable {
    /// Fill color, or `nil` for no fill.
    public var fill: Color?

    /// Stroke color, or `nil` for no stroke.
    public var stroke: Color?

    /// Fill rendering options.
    public var fillStyle: FillStyle

    /// Stroke rendering options, when stroke is present.
    public var strokeStyle: StrokeStyle?

    /// Blend mode for the styled draw.
    public var blendMode: BlendMode

    /// Opacity multiplier.
    public var opacity: Double

    /// Tint multiplier.
    public var tint: Color

    /// Creates a render style.
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
