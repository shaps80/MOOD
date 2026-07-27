import PixlGraphics

public struct Circle: Shape, Sendable {
    @inlinable public init() {}

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension Circle: _Shape {
    package func path(in rect: Rect) -> _ShapePath {
        let diameter = min(rect.size.width, rect.size.height)
        return .circle(
            .init(
                origin: rect.origin + (rect.size - Size(repeating: diameter)) * 0.5,
                size: .init(repeating: diameter)
            )
        )
    }
}

extension Shape where Self == Circle {
    public static var circle: Self { .init() }
}
