import Swift

@usableFromInline struct _PaddingLayout: Layout {
    @usableFromInline var insets: EdgeInsets

    @usableFromInline func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> Size {
        guard let child = subviews.first else { return .zero }
        let horizontal = insets.leading + insets.trailing
        let vertical = insets.top + insets.bottom
        let childSize = child.sizeThatFits(.init(
            width: proposal.width.map { max(0, $0 - horizontal) },
            height: proposal.height.map { max(0, $0 - vertical) }
        ))
        return .init(width: childSize.width + horizontal, height: childSize.height + vertical)
    }

    @usableFromInline func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard let child = subviews.first else { return }
        let childSize = Size(
            width: max(0, bounds.size.width - insets.leading - insets.trailing),
            height: max(0, bounds.size.height - insets.top - insets.bottom)
        )
        child.place(
            at: .init(x: bounds.minX + insets.leading, y: bounds.minY + insets.top),
            anchor: .topLeading,
            proposal: .init(childSize)
        )
    }
}
