import Pixl2D

public struct ConcentricRectangle: Shape, Sendable {
    public var topLeadingCorner: Edge.Corner.Style
    public var topTrailingCorner: Edge.Corner.Style
    public var bottomLeadingCorner: Edge.Corner.Style
    public var bottomTrailingCorner: Edge.Corner.Style
    var isUniform: Bool

    public init(
        topLeadingCorner: Edge.Corner.Style = .concentric,
        topTrailingCorner: Edge.Corner.Style = .concentric,
        bottomLeadingCorner: Edge.Corner.Style = .concentric,
        bottomTrailingCorner: Edge.Corner.Style = .concentric
    ) {
        self.topLeadingCorner = topLeadingCorner
        self.topTrailingCorner = topTrailingCorner
        self.bottomLeadingCorner = bottomLeadingCorner
        self.bottomTrailingCorner = bottomTrailingCorner
        isUniform = false
    }

    /// Creates a rectangle with the same corner style set on four corners.
    ///
    /// When you provide `false` for `isUniform`, the system may calculate
    /// a different radius for each corner. This can happen when the rectangle
    /// is not centered within the container shape, or the container shape's
    /// corners have different radii. When you provide `true` for `isUniform`,
    /// the system calculates the radius for each corner first. Then, it
    /// selects the largest radius and applies it to each corner to achieve
    /// the symmetric look.
    ///
    /// - Parameters:
    ///   - corners: The corner style for all four corners.
    ///   - isUniform: A Boolean value that indicates whether to apply the
    ///   corner style on each corner individually or uniformly.
    public init(_ corners: Edge.Corner.Style, isUniform: Bool = false) {
        topLeadingCorner = corners
        topTrailingCorner = corners
        bottomLeadingCorner = corners
        bottomTrailingCorner = corners
        self.isUniform = isUniform
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension ConcentricRectangle: _Shape {
    package func path(in rect: Rect) -> _ShapePath {
        .concentricRectangle(
            rect,
            corners: .init(
                topLeading: topLeadingCorner,
                topTrailing: topTrailingCorner,
                bottomLeading: bottomLeadingCorner,
                bottomTrailing: bottomTrailingCorner,
                isUniform: isUniform
            )
        )
    }
}

package struct _ConcentricCornerStyles: Sendable {
    package let topLeading: Edge.Corner.Style
    package let topTrailing: Edge.Corner.Style
    package let bottomLeading: Edge.Corner.Style
    package let bottomTrailing: Edge.Corner.Style
    package let isUniform: Bool
}

extension Shape where Self == ConcentricRectangle {
    public static var concentric: Self { .init() }

    public static func concentric(minimum: Edge.Corner.Style) -> Self {
        .init(minimum)
    }
}
