import Swift

/// Contiguous broad-phase storage for axis-aligned bounds.
public final class DynamicAABBTree2D {
    private static let initialCapacity = 16
    private static let nullIndex: Int32 = -1

    private var nodes: UnsafeMutablePointer<Node>
    private var capacity: Int
    private var nodeCount: Int32 = 0
    private var freeList: Int32

    /// Number of live proxies.
    public var count: Int {
        Int(nodeCount)
    }

    public init() {
        capacity = Self.initialCapacity
        nodes = .allocate(capacity: capacity)
        freeList = 0

        for index in 0..<capacity {
            let next = index + 1 < capacity
                ? Int32(index + 1)
                : Self.nullIndex
            nodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }
    }

    deinit {
        nodes.deinitialize(count: capacity)
        nodes.deallocate()
    }

    /// Stores bounds and returns their stable proxy identity.
    public func insert(_ bounds: Rect) -> ProxyID {
        if freeList == Self.nullIndex {
            grow()
        }

        let index = freeList
        let slot = nodes.advanced(by: Int(index))
        let generation = slot.pointee.generation
        freeList = slot.pointee.nextFree
        slot.pointee = .leaf(bounds: bounds, generation: generation)
        nodeCount += 1

        return ProxyID(index: index, generation: generation)
    }

    /// Removes a live proxy. Invalid and previously removed identities do nothing.
    public func remove(_ proxy: ProxyID) {
        guard let index = liveIndex(for: proxy) else {
            return
        }

        let slot = nodes.advanced(by: index)
        let generation = slot.pointee.generation &+ 1
        slot.pointee = .free(
            next: freeList,
            generation: generation
        )
        freeList = Int32(index)
        nodeCount -= 1
    }

    /// Returns the bounds for a live proxy.
    public func bounds(for proxy: ProxyID) -> Rect? {
        guard let index = liveIndex(for: proxy) else {
            return nil
        }

        return nodes[index].rect
    }

    private func liveIndex(for proxy: ProxyID) -> Int? {
        let index = Int(proxy.index)
        guard index >= 0, index < capacity else {
            return nil
        }

        let node = nodes[index]
        guard node.height >= 0, node.generation == proxy.generation else {
            return nil
        }

        return index
    }

    private func grow() {
        let oldCapacity = capacity
        let newCapacity = oldCapacity * 2
        let newNodes = UnsafeMutablePointer<Node>.allocate(
            capacity: newCapacity
        )
        newNodes.moveInitialize(from: nodes, count: oldCapacity)
        nodes.deallocate()

        for index in oldCapacity..<newCapacity {
            let next = index + 1 < newCapacity
                ? Int32(index + 1)
                : Self.nullIndex
            newNodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }

        nodes = newNodes
        capacity = newCapacity
        freeList = Int32(oldCapacity)
    }
}

private extension DynamicAABBTree2D {
    struct Node {
        var bounds: SIMD4<Float>
        var parent: Int32
        var childA: Int32
        var childB: Int32
        var height: Int32
        var nextFree: Int32
        var generation: UInt32

        var rect: Rect {
            Rect(
                x: bounds.x,
                y: bounds.y,
                width: bounds.z - bounds.x,
                height: bounds.w - bounds.y
            )
        }

        static func leaf(bounds: Rect, generation: UInt32) -> Self {
            Self(
                bounds: .init(
                    bounds.minX,
                    bounds.minY,
                    bounds.maxX,
                    bounds.maxY
                ),
                parent: DynamicAABBTree2D.nullIndex,
                childA: DynamicAABBTree2D.nullIndex,
                childB: DynamicAABBTree2D.nullIndex,
                height: 0,
                nextFree: DynamicAABBTree2D.nullIndex,
                generation: generation
            )
        }

        static func free(next: Int32, generation: UInt32) -> Self {
            Self(
                bounds: .zero,
                parent: DynamicAABBTree2D.nullIndex,
                childA: DynamicAABBTree2D.nullIndex,
                childB: DynamicAABBTree2D.nullIndex,
                height: -1,
                nextFree: next,
                generation: generation
            )
        }
    }
}
