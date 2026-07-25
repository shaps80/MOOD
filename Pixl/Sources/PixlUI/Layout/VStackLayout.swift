import Swift

public struct VStackLayout: Layout {
    public var alignment: HorizontalAlignment
    public var spacing: Float?
    public init(alignment: HorizontalAlignment = .center, spacing: Float? = nil) { self.alignment = alignment; self.spacing = spacing }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .vertical; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        var result = CGSize.zero
        var hasFlexible = false
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: proposal.width, height: nil)); result.width = max(result.width, size.width); result.height += size.height
            hasFlexible = hasFlexible || subview.sizeThatFits(.init(width: proposal.width, height: .infinity)).height.isInfinite
        }
        result.height += Float(max(0, subviews.count - 1)) * (spacing ?? 0)
        if hasFlexible, let height = proposal.height, height.isFinite { result.height = max(result.height, height) }
        return result
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var y = bounds.minY
        var fixed: Float = Float(max(0, subviews.count - 1)) * (spacing ?? 0), flexibleCount = 0
        for subview in subviews {
            if subview.sizeThatFits(.init(width: bounds.size.width, height: .infinity)).height.isInfinite { flexibleCount += 1 }
            else { fixed += subview.sizeThatFits(.init(width: bounds.size.width, height: nil)).height }
        }
        let share = flexibleCount == 0 ? 0 : max(0, bounds.size.height - fixed) / Float(flexibleCount)
        for subview in subviews {
            let isFlexible = subview.sizeThatFits(.init(width: bounds.size.width, height: .infinity)).height.isInfinite
            let size = subview.sizeThatFits(.init(width: bounds.size.width, height: isFlexible ? share : nil))
            let dimensions = ViewDimensions(size: size)
            let x = bounds.minX + ViewDimensions(size: bounds.size)[alignment] - dimensions[alignment]
            subview.place(at: .init(x: x, y: y), anchor: .topLeading, proposal: .init(size))
            y += size.height + (spacing ?? 0)
        }
    }
}
