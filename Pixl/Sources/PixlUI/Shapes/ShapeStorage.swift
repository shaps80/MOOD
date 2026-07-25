import Swift

@usableFromInline struct _ShapeStroke: Sendable {
    @usableFromInline let style: ViewGraph.StyleID
    @usableFromInline let lineWidth: Float
}

@usableFromInline struct _ShapeRecord: @unchecked Sendable {
    @usableFromInline let shape: _AnyShapeBox
    @usableFromInline let fill: ViewGraph.StyleID
    @usableFromInline let stroke: _ShapeStroke?
}

@usableFromInline class _AnyShapeBox: @unchecked Sendable {
    @usableFromInline func path(in rect: Rect) -> _ShapePath { fatalError() }
    @usableFromInline func sizeThatFits(_ proposal: ProposedViewSize) -> Size { fatalError() }
}

@usableFromInline final class _ShapeBox<S: _Shape>: _AnyShapeBox, @unchecked Sendable {
    @usableFromInline let shape: S
    @usableFromInline init(_ shape: S) { self.shape = shape }
    @usableFromInline override func path(in rect: Rect) -> _ShapePath { shape.path(in: rect) }
    @usableFromInline override func sizeThatFits(_ proposal: ProposedViewSize) -> Size { shape.sizeThatFits(proposal) }
}
