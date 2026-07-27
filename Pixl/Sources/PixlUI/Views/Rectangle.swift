import Swift

public struct Rectangle: Shape {
    public var cornerRadius: Float

    @inlinable public init(cornerRadius: Float = 0) {
        self.cornerRadius = max(0, cornerRadius)
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value, stroke: Optional<_NoShapeStyle>.none, lineWidth: 0, inputs: inputs)
    }

    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: Float = 1) -> some View {
        _StrokedShape(shape: self, style: style, lineWidth: lineWidth)
    }
}

extension Rectangle: _Shape {
    package func path(in rect: Rect) -> _ShapePath {
        .rectangle(rect, cornerRadius: cornerRadius)
    }
}

extension Shape where Self == Rectangle {
    public static var rect: Self { .init() }

    public static func rect(cornerRadius: Float) -> Self {
        .init(cornerRadius: cornerRadius)
    }
}

public typealias RoundedRectangle = Rectangle
