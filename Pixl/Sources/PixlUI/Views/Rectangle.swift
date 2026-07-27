import Swift

public struct Rectangle: Shape {
    @inlinable public init() { }
    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension Rectangle: _Shape {
    package func path(in rect: Rect) -> _ShapePath { .rectangle(rect) }
}

extension Shape where Self == Rectangle {
    public static var rect: Self { .init() }
}
