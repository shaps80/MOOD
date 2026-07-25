import Swift

public struct LayoutSubview: Equatable, @unchecked Sendable {
    @usableFromInline let storage: _LayoutSubviewStorage
    @usableFromInline let id: ViewGraph.NodeID
    @usableFromInline let orientation: Axis?

    @usableFromInline init(storage: _LayoutSubviewStorage, id: ViewGraph.NodeID, orientation: Axis?) {
        self.storage = storage; self.id = id; self.orientation = orientation
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.storage === rhs.storage && lhs.id == rhs.id }
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value { K.defaultValue }
    public var priority: Float { 0 }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { storage.sizeThatFits(id, proposal, orientation) }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { .init(size: sizeThatFits(proposal)) }
    public var spacing: ViewSpacing { storage.spacing(id) }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {
        storage.place(id, position, anchor, proposal, orientation)
    }
}

@usableFromInline class _LayoutSubviewStorage: @unchecked Sendable {
    @usableFromInline func sizeThatFits(_ id: ViewGraph.NodeID, _ proposal: ProposedViewSize, _ orientation: Axis?) -> CGSize { fatalError() }
    @usableFromInline func spacing(_ id: ViewGraph.NodeID) -> ViewSpacing { .zero }
    @usableFromInline func place(_ id: ViewGraph.NodeID, _ position: CGPoint, _ anchor: UnitPoint, _ proposal: ProposedViewSize, _ orientation: Axis?) { fatalError() }
}
