import Swift

public protocol Layout: Sendable {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews

    static var layoutProperties: LayoutProperties { get }
    func makeCache(subviews: Subviews) -> Cache
    func updateCache(_ cache: inout Cache, subviews: Subviews)
    func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size
    func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float?
    func explicitAlignment(of guide: VerticalAlignment, in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float?
}

extension Layout {
    public static var layoutProperties: LayoutProperties { .init() }
    public func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = makeCache(subviews: subviews) }
    public func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing {
        subviews.reduce(into: .zero) { $0.formUnion($1.spacing) }
    }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float? { nil }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Float? { nil }

    public func callAsFunction<Content: View>(
        @ContentBuilder content: () -> Content
    ) -> some View {
        _LayoutView(layout: self, content: content())
    }
}

extension Layout where Cache == Void {
    public func makeCache(subviews: Subviews) -> Void { () }
}
