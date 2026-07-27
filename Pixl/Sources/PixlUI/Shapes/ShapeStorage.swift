import Swift

package struct _ShapeStroke: Sendable {
    package let style: ViewGraph.StyleID
    package let lineWidth: Float
}

package struct _ShapeRecord: @unchecked Sendable {
    package let shape: _AnyShapeBox
    package var fill: ViewGraph.StyleID
    package let stroke: _ShapeStroke?
    package let containerShape: ViewGraph.NodeID

    package func path(in rect: Rect, displayScale: Float) -> _ShapePath {
        let path = shape.path(in: rect)
        guard let stroke, stroke.lineWidth > 0 else { return path }

        switch path {
        case .rectangle(let rect, let cornerRadius):
            let alignedMinX = (rect.minX * displayScale).rounded() / displayScale
            let alignedMinY = (rect.minY * displayScale).rounded() / displayScale
            let alignedMaxX = (rect.maxX * displayScale).rounded() / displayScale
            let alignedMaxY = (rect.maxY * displayScale).rounded() / displayScale
            let halfWidth = stroke.lineWidth * 0.5
            return .rectangle(
                .init(
                    x: alignedMinX + halfWidth,
                    y: alignedMinY + halfWidth,
                    width: max(0, alignedMaxX - alignedMinX - stroke.lineWidth),
                    height: max(0, alignedMaxY - alignedMinY - stroke.lineWidth)
                ),
                cornerRadius: max(0, cornerRadius - halfWidth)
            )
        case .unevenRoundedRectangle(let rect, let cornerRadii):
            let alignedMinX = (rect.minX * displayScale).rounded() / displayScale
            let alignedMinY = (rect.minY * displayScale).rounded() / displayScale
            let alignedMaxX = (rect.maxX * displayScale).rounded() / displayScale
            let alignedMaxY = (rect.maxY * displayScale).rounded() / displayScale
            let halfWidth = stroke.lineWidth * 0.5
            return .unevenRoundedRectangle(
                .init(
                    x: alignedMinX + halfWidth,
                    y: alignedMinY + halfWidth,
                    width: max(0, alignedMaxX - alignedMinX - stroke.lineWidth),
                    height: max(0, alignedMaxY - alignedMinY - stroke.lineWidth)
                ),
                cornerRadii: .init(
                    topLeading: max(0, cornerRadii.topLeading - halfWidth),
                    bottomLeading: max(0, cornerRadii.bottomLeading - halfWidth),
                    bottomTrailing: max(0, cornerRadii.bottomTrailing - halfWidth),
                    topTrailing: max(0, cornerRadii.topTrailing - halfWidth)
                )
            )
        case .concentricRectangle(let rect, let corners):
            let alignedMinX = (rect.minX * displayScale).rounded() / displayScale
            let alignedMinY = (rect.minY * displayScale).rounded() / displayScale
            let alignedMaxX = (rect.maxX * displayScale).rounded() / displayScale
            let alignedMaxY = (rect.maxY * displayScale).rounded() / displayScale
            let halfWidth = stroke.lineWidth * 0.5
            return .concentricRectangle(
                .init(
                    x: alignedMinX + halfWidth,
                    y: alignedMinY + halfWidth,
                    width: max(0, alignedMaxX - alignedMinX - stroke.lineWidth),
                    height: max(0, alignedMaxY - alignedMinY - stroke.lineWidth)
                ),
                corners: corners
            )
        case .circle(let rect):
            let alignedMinX = (rect.minX * displayScale).rounded() / displayScale
            let alignedMinY = (rect.minY * displayScale).rounded() / displayScale
            let alignedMaxX = (rect.maxX * displayScale).rounded() / displayScale
            let alignedMaxY = (rect.maxY * displayScale).rounded() / displayScale
            let halfWidth = stroke.lineWidth * 0.5
            return .circle(
                .init(
                    x: alignedMinX + halfWidth,
                    y: alignedMinY + halfWidth,
                    width: max(0, alignedMaxX - alignedMinX - stroke.lineWidth),
                    height: max(0, alignedMaxY - alignedMinY - stroke.lineWidth)
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
