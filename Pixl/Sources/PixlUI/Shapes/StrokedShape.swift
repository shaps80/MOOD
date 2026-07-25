import Swift

@usableFromInline struct _StrokedShape<Content: _Shape, Style: ShapeStyle>: View {
    @usableFromInline let shape: Content
    @usableFromInline let style: Style
    @usableFromInline let lineWidth: Float

    @usableFromInline init(shape: Content, style: Style, lineWidth: Float) {
        self.shape = shape
        self.style = style
        self.lineWidth = lineWidth
    }

    @usableFromInline var body: Never { fatalError() }

    @usableFromInline static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value.shape, stroke: view.value.style, lineWidth: view.value.lineWidth, inputs: inputs)
    }
}
