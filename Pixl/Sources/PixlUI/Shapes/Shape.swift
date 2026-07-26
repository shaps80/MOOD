import Swift

package protocol _Shape: Sendable {
    func path(in rect: Rect) -> _ShapePath
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size
}

extension _Shape {
    package func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        proposal.replacingUnspecifiedDimensions()
    }
}
