import Swift

public struct VStackLayout: Layout {
    public var alignment: HorizontalAlignment
    public var spacing: Float
    public init(alignment: HorizontalAlignment = .center, spacing: Float? = nil) { self.alignment = alignment; self.spacing = spacing ?? 10 }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .vertical; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        let allocations = _StackLayout.allocate(subviews, along: .vertical, proposal: proposal.height, cross: proposal.width, spacing: spacing)
        var result = Size(width: 0, height: Float(max(0, subviews.count - 1)) * spacing)
        for allocation in allocations {
            result.width = max(result.width, allocation.size.width)
            result.height += allocation.size.height
        }
        return result
    }
    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let allocations = _StackLayout.allocate(subviews, along: .vertical, proposal: bounds.size.height, cross: bounds.size.width, spacing: spacing)
        var y = bounds.minY
        for allocation in allocations {
            let subview = subviews[allocation.index]
            let size = allocation.size
            let dimensions = ViewDimensions(size: size)
            let x = bounds.minX + ViewDimensions(size: bounds.size)[alignment] - dimensions[alignment]
            subview.place(at: .init(x: x, y: y), anchor: .topLeading, proposal: .init(size))
            y += size.height + spacing
        }
    }
}
