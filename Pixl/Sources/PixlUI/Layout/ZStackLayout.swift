import Swift

public struct ZStackLayout: Layout {
    public var alignment: Alignment
    public init(alignment: Alignment = .center) { self.alignment = alignment }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        subviews.reduce(into: .zero) { result, subview in let size = subview.sizeThatFits(proposal); result.width = max(result.width, size.width); result.height = max(result.height, size.height) }
    }
    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let container = ViewDimensions(size: bounds.size)
        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            let child = ViewDimensions(size: size)
            let point = Point(x: bounds.minX + container[alignment.horizontal] - child[alignment.horizontal], y: bounds.minY + container[alignment.vertical] - child[alignment.vertical])
            subview.place(at: point, anchor: .topLeading, proposal: .init(size))
        }
    }
}
