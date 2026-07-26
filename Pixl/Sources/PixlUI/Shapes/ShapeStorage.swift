import Swift

package struct _ShapeStroke: Sendable {
    package let style: ViewGraph.StyleID
    package let lineWidth: Float
}

package struct _ShapeRecord: @unchecked Sendable {
    package let shape: _AnyShapeBox
    package var fill: ViewGraph.StyleID
    package let stroke: _ShapeStroke?

    package func path(in rect: Rect, displayScale: Float) -> _ShapePath {
        let path = shape.path(in: rect)
        guard let stroke, stroke.lineWidth > 0 else { return path }

        switch path {
        case .rectangle(let rect):
            let outwardPixels = stroke.lineWidth * displayScale * 0.5
            let alignedMinX = (
                (rect.minX * displayScale - outwardPixels).rounded()
                    + outwardPixels
            ) / displayScale
            let alignedMinY = (
                (rect.minY * displayScale - outwardPixels).rounded()
                    + outwardPixels
            ) / displayScale
            return .rectangle(
                rect.translated(
                    by: .init(
                        x: alignedMinX - rect.minX,
                        y: alignedMinY - rect.minY
                    )
                )
            )
        }
    }
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
