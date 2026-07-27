import Swift

public protocol Shape: View, Sendable { }

package protocol _Shape: Shape {
    func path(in rect: Rect) -> _ShapePath
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size
}

extension _Shape {
    package func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        proposal.replacingUnspecifiedDimensions()
    }
}
