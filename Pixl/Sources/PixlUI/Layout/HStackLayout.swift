import Swift

public struct HStackLayout: Layout {
    public var alignment: VerticalAlignment
    public var spacing: Float
    public init(alignment: VerticalAlignment = .center, spacing: Float? = nil) { self.alignment = alignment; self.spacing = spacing ?? 10 }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .horizontal; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        var result = Size.zero
        var hasFlexible = false
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: nil, height: proposal.height)); result.width += size.width; result.height = max(result.height, size.height)
            hasFlexible = hasFlexible || subview.sizeThatFits(.init(width: .infinity, height: proposal.height)).width.isInfinite
        }
        result.width += Float(max(0, subviews.count - 1)) * spacing
        if hasFlexible, let width = proposal.width, width.isFinite { result.width = max(result.width, width) }
        return result
    }
    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var fixed: Float = Float(max(0, subviews.count - 1)) * spacing, flexibleCount = 0
        for subview in subviews {
            if subview.sizeThatFits(.init(width: .infinity, height: bounds.size.height)).width.isInfinite { flexibleCount += 1 }
            else { fixed += subview.sizeThatFits(.init(width: nil, height: bounds.size.height)).width }
        }
        let share = flexibleCount == 0 ? 0 : max(0, bounds.size.width - fixed) / Float(flexibleCount)
        for subview in subviews {
            let isFlexible = subview.sizeThatFits(.init(width: .infinity, height: bounds.size.height)).width.isInfinite
            let size = subview.sizeThatFits(.init(width: isFlexible ? share : nil, height: bounds.size.height))
            let dimensions = ViewDimensions(size: size)
            let y = bounds.minY + ViewDimensions(size: bounds.size)[alignment] - dimensions[alignment]
            subview.place(at: .init(x: x, y: y), anchor: .topLeading, proposal: .init(size))
            x += size.width + spacing
        }
    }
}
