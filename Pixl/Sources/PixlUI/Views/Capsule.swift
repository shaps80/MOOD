import PixlGraphics

public struct Capsule: Shape, Sendable {
    @inlinable public init() {}

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension Capsule: _Shape {
    package func path(in rect: Rect) -> _ShapePath {
        .rectangle(
            rect,
            cornerRadius: min(rect.size.width, rect.size.height) * 0.5
        )
    }
}

extension Shape where Self == Capsule {
    public static var capsule: Self { .init() }
}
