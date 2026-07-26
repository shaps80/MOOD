import Swift

package struct _ShapeStroke: Sendable {
    package let style: ViewGraph.StyleID
    package let lineWidth: Float
}

package struct _ShapeRecord: @unchecked Sendable {
    package let shape: _AnyShapeBox
    package let fill: ViewGraph.StyleID
    package let stroke: _ShapeStroke?
}

package class _AnyShapeBox: @unchecked Sendable {
    package func path(in rect: Rect) -> _ShapePath { fatalError() }
    package func sizeThatFits(_ proposal: ProposedViewSize) -> Size { fatalError() }
}

package final class _ShapeBox<S: _Shape>: _AnyShapeBox, @unchecked Sendable {
    let shape: S
    init(_ shape: S) { self.shape = shape }
    package override func path(in rect: Rect) -> _ShapePath { shape.path(in: rect) }
    package override func sizeThatFits(_ proposal: ProposedViewSize) -> Size { shape.sizeThatFits(proposal) }
}
