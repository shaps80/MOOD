import Pixl2D

extension UnevenRoundedRectangle: Shape {
    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension UnevenRoundedRectangle: _Shape {
    package func path(in rect: Rect) -> _ShapePath {
        .unevenRoundedRectangle(rect, cornerRadii: cornerRadii)
    }
}
