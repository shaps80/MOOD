import Swift

public struct LayoutSubviews: Equatable, RandomAccessCollection, @unchecked Sendable {
    public typealias Element = LayoutSubview
    public typealias Index = Int
    public typealias SubSequence = LayoutSubviews

    @usableFromInline let storage: _LayoutSubviewStorage
    @usableFromInline let ids: ContiguousArray<ViewGraph.NodeID>
    @usableFromInline let bounds: Range<Int>
    @usableFromInline let orientation: Axis?
    public let layoutDirection: LayoutDirection

    @usableFromInline init(storage: _LayoutSubviewStorage, ids: ContiguousArray<ViewGraph.NodeID>, bounds: Range<Int>? = nil, orientation: Axis?, layoutDirection: LayoutDirection = .leftToRight) {
        self.storage = storage; self.ids = ids; self.bounds = bounds ?? ids.indices; self.orientation = orientation; self.layoutDirection = layoutDirection
    }

    public var startIndex: Int { bounds.lowerBound }
    public var endIndex: Int { bounds.upperBound }
    public subscript(index: Int) -> Element { .init(storage: storage, id: ids[index], orientation: orientation) }
    public subscript(bounds: Range<Int>) -> LayoutSubviews { .init(storage: storage, ids: ids, bounds: bounds, orientation: orientation, layoutDirection: layoutDirection) }
    public subscript<S: Sequence>(indices: S) -> LayoutSubviews where S.Element == Int {
        .init(storage: storage, ids: .init(indices.map { ids[$0] }), orientation: orientation, layoutDirection: layoutDirection)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.storage === rhs.storage && lhs.ids == rhs.ids && lhs.bounds == rhs.bounds }
}
