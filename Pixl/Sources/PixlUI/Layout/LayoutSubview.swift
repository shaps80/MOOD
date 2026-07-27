import Swift

public struct LayoutSubview: Equatable, @unchecked Sendable {
    let storage: _LayoutSubviewStorage
    let id: ViewGraph.NodeID
    let orientation: Axis?

    init(storage: _LayoutSubviewStorage, id: ViewGraph.NodeID, orientation: Axis?) {
        self.storage = storage; self.id = id; self.orientation = orientation
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.storage === rhs.storage && lhs.id == rhs.id }
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value { K.defaultValue }
    public var priority: Float { 0 }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> Size { storage.sizeThatFits(id, proposal, orientation) }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { .init(size: sizeThatFits(proposal)) }
    public var spacing: ViewSpacing { storage.spacing(id) }
    public func place(at position: Point, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {
        storage.place(id, position, anchor, proposal, orientation)
    }
}

extension LayoutSubview {
    func flexibility(along axis: Axis, cross: Float?) -> _LayoutFlexibility {
        func proposal(_ value: Float?) -> ProposedViewSize {
            switch axis {
            case .horizontal: .init(width: value, height: cross)
            case .vertical: .init(width: cross, height: value)
            }
        }

        func dimension(_ value: Float?) -> Float {
            let size = sizeThatFits(proposal(value))
            return axis == .horizontal ? size.width : size.height
        }

        return .init(
            minimum: dimension(0),
            ideal: dimension(nil),
            maximum: dimension(.infinity)
        )
    }
}

class _LayoutSubviewStorage: @unchecked Sendable {
    func sizeThatFits(_ id: ViewGraph.NodeID, _ proposal: ProposedViewSize, _ orientation: Axis?) -> Size { fatalError() }
    func spacing(_ id: ViewGraph.NodeID) -> ViewSpacing { .zero }
    func place(_ id: ViewGraph.NodeID, _ position: Point, _ anchor: UnitPoint, _ proposal: ProposedViewSize, _ orientation: Axis?) { fatalError() }
}
