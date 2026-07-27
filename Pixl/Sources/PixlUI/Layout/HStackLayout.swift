import Swift

public struct HStackLayout: Layout {
    public var alignment: VerticalAlignment
    public var spacing: Float
    public init(alignment: VerticalAlignment = .center, spacing: Float? = nil) { self.alignment = alignment; self.spacing = spacing ?? 10 }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .horizontal; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        let allocations = _StackLayout.allocate(subviews, along: .horizontal, proposal: proposal.width, cross: proposal.height, spacing: spacing)
        var result = Size(width: Float(max(0, subviews.count - 1)) * spacing, height: 0)
        for allocation in allocations {
            result.width += allocation.size.width
            result.height = max(result.height, allocation.size.height)
        }
        return result
    }
    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let allocations = _StackLayout.allocate(subviews, along: .horizontal, proposal: bounds.size.width, cross: bounds.size.height, spacing: spacing)
        var x = bounds.minX
        for allocation in allocations {
            let subview = subviews[allocation.index]
            let size = allocation.size
            let dimensions = ViewDimensions(size: size)
            let y = bounds.minY + ViewDimensions(size: bounds.size)[alignment] - dimensions[alignment]
            subview.place(at: .init(x: x, y: y), anchor: .topLeading, proposal: .init(size))
            x += size.width + spacing
        }
    }
}
