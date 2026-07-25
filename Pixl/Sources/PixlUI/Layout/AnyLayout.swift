import Swift

public struct AnyLayout: Layout, @unchecked Sendable {
    public struct Cache { @usableFromInline var value: Any? }
    @usableFromInline let box: _AnyLayoutBox

    public init<L: Layout>(_ layout: L) { box = _LayoutBox(layout) }
    public static var layoutProperties: LayoutProperties { .init() }
    public func makeCache(subviews: Subviews) -> Cache { .init(value: box.makeCache(subviews: subviews)) }
    public func updateCache(_ cache: inout Cache, subviews: Subviews) { box.updateCache(&cache.value, subviews: subviews) }
    public func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing { box.spacing(subviews: subviews, cache: &cache.value) }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize { box.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache.value) }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) { box.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value) }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float? { box.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value) }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float? { box.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value) }
}

@usableFromInline class _AnyLayoutBox: @unchecked Sendable {
    @usableFromInline var debugName: String { "Layout" }
    @usableFromInline var layoutProperties: LayoutProperties { .init() }
    @usableFromInline func makeCache(subviews: LayoutSubviews) -> Any { fatalError() }
    @usableFromInline func updateCache(_ cache: inout Any?, subviews: LayoutSubviews) { fatalError() }
    @usableFromInline func spacing(subviews: LayoutSubviews, cache: inout Any?) -> ViewSpacing { fatalError() }
    @usableFromInline func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> CGSize { fatalError() }
    @usableFromInline func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) { fatalError() }
    @usableFromInline func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> Float? { fatalError() }
    @usableFromInline func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> Float? { fatalError() }
}

@usableFromInline final class _LayoutBox<L: Layout>: _AnyLayoutBox, @unchecked Sendable {
    @usableFromInline let layout: L
    @usableFromInline let properties: LayoutProperties
    @usableFromInline init(_ layout: L) { self.layout = layout; properties = (layout as? AnyLayout)?.box.layoutProperties ?? L.layoutProperties }
    @usableFromInline override var layoutProperties: LayoutProperties { properties }
    @usableFromInline override var debugName: String {
        switch String(describing: L.self) {
        case "VStackLayout": return "VStack"
        case "HStackLayout": return "HStack"
        case "ZStackLayout": return "ZStack"
        case "_FrameLayout": return "Frame"
        case "_PaddingLayout": return "Padding"
        default: return String(describing: L.self)
        }
    }
    @usableFromInline override func makeCache(subviews: LayoutSubviews) -> Any { layout.makeCache(subviews: subviews) }
    @usableFromInline override func updateCache(_ cache: inout Any?, subviews: LayoutSubviews) { var value = cache as! L.Cache; layout.updateCache(&value, subviews: subviews); cache = value }
    @usableFromInline override func spacing(subviews: LayoutSubviews, cache: inout Any?) -> ViewSpacing { var value = cache as! L.Cache; let result = layout.spacing(subviews: subviews, cache: &value); cache = value; return result }
    @usableFromInline override func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> CGSize { var value = cache as! L.Cache; let result = layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &value); cache = value; return result }
    @usableFromInline override func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) { var value = cache as! L.Cache; layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &value); cache = value }
    @usableFromInline override func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> Float? { var value = cache as! L.Cache; let result = layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &value); cache = value; return result }
    @usableFromInline override func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any?) -> Float? { var value = cache as! L.Cache; let result = layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &value); cache = value; return result }
}
