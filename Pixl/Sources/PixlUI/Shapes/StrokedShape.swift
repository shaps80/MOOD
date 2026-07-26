import Swift

package struct _StrokedShape<Content: _Shape, Style: ShapeStyle>: View {
    let shape: Content
    let style: Style
    let lineWidth: Float

    init(shape: Content, style: Style, lineWidth: Float) {
        self.shape = shape
        self.style = style
        self.lineWidth = lineWidth
    }

    package var body: Never { fatalError() }

    package static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _makeShapeView(shape: view.value.shape, stroke: view.value.style, lineWidth: view.value.lineWidth, inputs: inputs)
    }
}
