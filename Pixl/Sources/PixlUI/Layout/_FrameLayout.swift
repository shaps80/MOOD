import Swift

@usableFromInline struct _FrameLayout: Layout {
    @usableFromInline var minWidth: Float?
    @usableFromInline var idealWidth: Float?
    @usableFromInline var maxWidth: Float?
    @usableFromInline var minHeight: Float?
    @usableFromInline var idealHeight: Float?
    @usableFromInline var maxHeight: Float?
    @usableFromInline var alignment: Alignment

    @usableFromInline init(_ modifier: _FrameModifier) {
        minWidth = modifier.minWidth; idealWidth = modifier.idealWidth; maxWidth = modifier.maxWidth
        minHeight = modifier.minHeight; idealHeight = modifier.idealHeight; maxHeight = modifier.maxHeight
        alignment = modifier.alignment
    }

    @usableFromInline func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> Size {
        guard let child = subviews.first else { return .zero }
        let childProposal = ProposedViewSize(
            width: proposed(proposal.width, min: minWidth, ideal: idealWidth, max: maxWidth),
            height: proposed(proposal.height, min: minHeight, ideal: idealHeight, max: maxHeight)
        )
        let childSize = child.sizeThatFits(childProposal)
        return .init(
            width: resolved(childSize.width, proposal: proposal.width, min: minWidth, ideal: idealWidth, max: maxWidth),
            height: resolved(childSize.height, proposal: proposal.height, min: minHeight, ideal: idealHeight, max: maxHeight)
        )
    }

    @usableFromInline func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard let child = subviews.first else { return }
        let childSize = child.sizeThatFits(.init(bounds.size))
        let container = ViewDimensions(size: bounds.size)
        let dimensions = ViewDimensions(size: childSize)
        child.place(
            at: .init(
                x: bounds.minX + container[alignment.horizontal] - dimensions[alignment.horizontal],
                y: bounds.minY + container[alignment.vertical] - dimensions[alignment.vertical]
            ),
            anchor: .topLeading,
            proposal: .init(childSize)
        )
    }

    private func proposed(_ proposal: Float?, min: Float?, ideal: Float?, max: Float?) -> Float? {
        if let min, let max, min == max { return min }
        guard let proposal else { return ideal }
        return Swift.max(min ?? -.infinity, Swift.min(max ?? .infinity, proposal))
    }

    private func resolved(_ child: Float, proposal: Float?, min: Float?, ideal: Float?, max: Float?) -> Float {
        if let min, let max, min == max { return min }
        var value = child
        if proposal == nil, let ideal { value = ideal }
        if min != nil || ideal != nil || max != nil, let proposal {
            let proposed = Swift.max(min ?? -.infinity, Swift.min(max ?? .infinity, proposal))
            value = Swift.max(child, proposed)
        }
        return Swift.max(min ?? -.infinity, Swift.min(max ?? .infinity, value))
    }
}
