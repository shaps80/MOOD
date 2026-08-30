import Swift

/// A balanced, allocation-free-in-steady-state broad-phase index for 2D bounds.
public final class DynamicAABBTree2D {
    private static let initialProxyCapacity = 16
    private static let nullIndex: Int32 = -1

    private var nodes: UnsafeMutablePointer<Node>
    private var capacity: Int
    private var allocatedNodeCount: Int32 = 0
    private var proxyCount: Int32 = 0
    private var freeList: Int32
    private var root: Int32 = nullIndex

    public var count: Int { Int(proxyCount) }

    /// Current tree height. An empty tree has height zero.
    public var height: Int {
        root == Self.nullIndex ? 0 : Int(nodes[Int(root)].height)
    }

    public init() {
        capacity = (Self.initialProxyCapacity * 2) - 1
        nodes = .allocate(capacity: capacity)
        freeList = 0

        for index in 0..<capacity {
            let next = index + 1 < capacity ? Int32(index + 1) : Self.nullIndex
            nodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }
    }

    deinit {
        nodes.deinitialize(count: capacity)
        nodes.deallocate()
    }

    public func insert(_ bounds: Rect) -> ProxyID {
        let leaf = allocateNode()
        let generation = nodes[Int(leaf)].generation
        nodes[Int(leaf)] = .leaf(bounds: bounds, generation: generation)
        insertLeaf(leaf)
        proxyCount += 1
        return ProxyID(index: leaf, generation: generation)
    }

    public func remove(_ proxy: ProxyID) {
        guard let leaf = liveIndex(for: proxy) else { return }
        removeLeaf(Int32(leaf))
        freeNode(Int32(leaf))
        proxyCount -= 1
    }

    public func bounds(for proxy: ProxyID) -> Rect? {
        guard let index = liveIndex(for: proxy) else { return nil }
        return nodes[index].rect
    }

    /// Returns the nearest proxy intersected by an infinite ray.
    public func intersection(with ray: Ray2D) -> RayIntersection2D? {
        let direction = ray.normalizedDirection
        guard root != Self.nullIndex,
              ray.origin.isValid,
              direction != .zero
        else { return nil }

        var nearestDistance = Float.infinity
        var nearest: RayIntersection2D?
        var previous = Self.nullIndex
        var current = root

        // Parent links provide a stackless depth-first traversal.
        while current != Self.nullIndex {
            let node = nodes[Int(current)]
            let next: Int32

            if previous == node.parent {
                if !rayIntersects(
                    node.bounds,
                    ray: ray,
                    maximumDistance: nearestDistance
                ) {
                    next = node.parent
                } else if node.isLeaf {
                    if let hit = node.rect.intersection(with: ray),
                       hit.distance < nearestDistance
                    {
                        nearestDistance = hit.distance
                        nearest = .init(
                            proxy: .init(
                                index: current,
                                generation: node.generation
                            ),
                            hit: hit
                        )
                    }
                    next = node.parent
                } else {
                    next = node.childA
                }
            } else if previous == node.childA {
                next = node.childB
            } else {
                next = node.parent
            }

            previous = current
            current = next
        }

        return nearest
    }

    private func liveIndex(for proxy: ProxyID) -> Int? {
        let index = Int(proxy.index)
        guard index >= 0, index < capacity else { return nil }
        let node = nodes[index]
        guard node.height == 0, node.generation == proxy.generation else {
            return nil
        }
        return index
    }

    private func allocateNode() -> Int32 {
        if freeList == Self.nullIndex { grow() }

        let index = freeList
        let slot = nodes.advanced(by: Int(index))
        let generation = slot.pointee.generation
        freeList = slot.pointee.nextFree
        slot.pointee = .allocated(generation: generation)
        allocatedNodeCount += 1
        return index
    }

    private func freeNode(_ index: Int32) {
        let slot = nodes.advanced(by: Int(index))
        let generation = slot.pointee.generation &+ 1
        slot.pointee = .free(next: freeList, generation: generation)
        freeList = index
        allocatedNodeCount -= 1
    }

    private func grow() {
        let oldCapacity = capacity
        let newCapacity = oldCapacity + max(oldCapacity / 2, 1)
        let newNodes = UnsafeMutablePointer<Node>.allocate(capacity: newCapacity)
        newNodes.moveInitialize(from: nodes, count: oldCapacity)
        nodes.deallocate()

        for index in oldCapacity..<newCapacity {
            let next = index + 1 < newCapacity ? Int32(index + 1) : Self.nullIndex
            newNodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }

        nodes = newNodes
        capacity = newCapacity
        freeList = Int32(oldCapacity)
    }

    private func insertLeaf(_ leaf: Int32) {
        if root == Self.nullIndex {
            root = leaf
            nodes[Int(leaf)].parent = Self.nullIndex
            return
        }

        let sibling = bestSibling(for: nodes[Int(leaf)].bounds)
        let oldParent = nodes[Int(sibling)].parent
        let newParent = allocateNode()
        let generation = nodes[Int(newParent)].generation
        nodes[Int(newParent)] = .branch(
            bounds: Self.union(nodes[Int(leaf)].bounds, nodes[Int(sibling)].bounds),
            parent: oldParent,
            childA: sibling,
            childB: leaf,
            height: nodes[Int(sibling)].height + 1,
            generation: generation
        )
        nodes[Int(sibling)].parent = newParent
        nodes[Int(leaf)].parent = newParent

        if oldParent == Self.nullIndex {
            root = newParent
        } else if nodes[Int(oldParent)].childA == sibling {
            nodes[Int(oldParent)].childA = newParent
        } else {
            nodes[Int(oldParent)].childB = newParent
        }

        var index = newParent
        while index != Self.nullIndex {
            recompute(index)
            rotate(index)
            index = nodes[Int(index)].parent
        }
    }

    private func removeLeaf(_ leaf: Int32) {
        if leaf == root {
            root = Self.nullIndex
            return
        }

        let parent = nodes[Int(leaf)].parent
        let grandParent = nodes[Int(parent)].parent
        let sibling = nodes[Int(parent)].childA == leaf
            ? nodes[Int(parent)].childB
            : nodes[Int(parent)].childA

        if grandParent == Self.nullIndex {
            root = sibling
            nodes[Int(sibling)].parent = Self.nullIndex
            freeNode(parent)
            return
        }

        if nodes[Int(grandParent)].childA == parent {
            nodes[Int(grandParent)].childA = sibling
        } else {
            nodes[Int(grandParent)].childB = sibling
        }
        nodes[Int(sibling)].parent = grandParent
        freeNode(parent)

        var index = grandParent
        while index != Self.nullIndex {
            recompute(index)
            rotate(index)
            index = nodes[Int(index)].parent
        }
    }

    private func bestSibling(for leafBounds: SIMD4<Float>) -> Int32 {
        var index = root

        while !nodes[Int(index)].isLeaf {
            let node = nodes[Int(index)]
            let childA = node.childA
            let childB = node.childB
            let area = Self.perimeter(node.bounds)
            let combinedArea = Self.perimeter(Self.union(node.bounds, leafBounds))
            let parentCost = 2 * combinedArea
            let inheritedCost = 2 * (combinedArea - area)
            let costA = insertionCost(
                child: childA,
                leafBounds: leafBounds,
                inheritedCost: inheritedCost
            )
            let costB = insertionCost(
                child: childB,
                leafBounds: leafBounds,
                inheritedCost: inheritedCost
            )

            if parentCost < costA, parentCost < costB { break }
            index = costA < costB ? childA : childB
        }

        return index
    }

    private func insertionCost(
        child: Int32,
        leafBounds: SIMD4<Float>,
        inheritedCost: Float
    ) -> Float {
        let node = nodes[Int(child)]
        let combinedArea = Self.perimeter(Self.union(node.bounds, leafBounds))
        if node.isLeaf { return combinedArea + inheritedCost }
        return combinedArea - Self.perimeter(node.bounds) + inheritedCost
    }

    private func recompute(_ index: Int32) {
        let childA = nodes[Int(index)].childA
        let childB = nodes[Int(index)].childB
        guard childA != Self.nullIndex, childB != Self.nullIndex else { return }
        nodes[Int(index)].bounds = Self.union(
            nodes[Int(childA)].bounds,
            nodes[Int(childB)].bounds
        )
        nodes[Int(index)].height = 1 + max(
            nodes[Int(childA)].height,
            nodes[Int(childB)].height
        )
    }

    /// Box2D-style local surface-area rotations. The root index never changes.
    private func rotate(_ index: Int32) {
        let childA = nodes[Int(index)].childA
        let childB = nodes[Int(index)].childB
        guard childA != Self.nullIndex,
              childB != Self.nullIndex,
              nodes[Int(index)].height >= 2
        else { return }

        var bestRotation = 0
        var bestCost = Self.perimeter(nodes[Int(childA)].bounds)
            + Self.perimeter(nodes[Int(childB)].bounds)

        if !nodes[Int(childB)].isLeaf {
            let childBA = nodes[Int(childB)].childA
            let childBB = nodes[Int(childB)].childB
            let costA = Self.perimeter(nodes[Int(childA)].bounds)
                + Self.perimeter(Self.union(
                    nodes[Int(childA)].bounds,
                    nodes[Int(childBB)].bounds
                ))
            if costA < bestCost {
                bestCost = costA
                bestRotation = 1
            }
            let costB = Self.perimeter(nodes[Int(childA)].bounds)
                + Self.perimeter(Self.union(
                    nodes[Int(childA)].bounds,
                    nodes[Int(childBA)].bounds
                ))
            if costB < bestCost {
                bestCost = costB
                bestRotation = 2
            }
        }

        if !nodes[Int(childA)].isLeaf {
            let childAA = nodes[Int(childA)].childA
            let childAB = nodes[Int(childA)].childB
            let costA = Self.perimeter(nodes[Int(childB)].bounds)
                + Self.perimeter(Self.union(
                    nodes[Int(childB)].bounds,
                    nodes[Int(childAB)].bounds
                ))
            if costA < bestCost {
                bestCost = costA
                bestRotation = 3
            }
            let costB = Self.perimeter(nodes[Int(childB)].bounds)
                + Self.perimeter(Self.union(
                    nodes[Int(childB)].bounds,
                    nodes[Int(childAA)].bounds
                ))
            if costB < bestCost { bestRotation = 4 }
        }

        switch bestRotation {
        case 1:
            let grandchild = nodes[Int(childB)].childA
            nodes[Int(index)].childA = grandchild
            nodes[Int(childB)].childA = childA
            nodes[Int(grandchild)].parent = index
            nodes[Int(childA)].parent = childB
            recompute(childB)
            recompute(index)
        case 2:
            let grandchild = nodes[Int(childB)].childB
            nodes[Int(index)].childA = grandchild
            nodes[Int(childB)].childB = childA
            nodes[Int(grandchild)].parent = index
            nodes[Int(childA)].parent = childB
            recompute(childB)
            recompute(index)
        case 3:
            let grandchild = nodes[Int(childA)].childA
            nodes[Int(index)].childB = grandchild
            nodes[Int(childA)].childA = childB
            nodes[Int(grandchild)].parent = index
            nodes[Int(childB)].parent = childA
            recompute(childA)
            recompute(index)
        case 4:
            let grandchild = nodes[Int(childA)].childB
            nodes[Int(index)].childB = grandchild
            nodes[Int(childA)].childB = childB
            nodes[Int(grandchild)].parent = index
            nodes[Int(childB)].parent = childA
            recompute(childA)
            recompute(index)
        default:
            break
        }
    }

    private func rayIntersects(
        _ bounds: SIMD4<Float>,
        ray: Ray2D,
        maximumDistance: Float
    ) -> Bool {
        let direction = ray.normalizedDirection
        var nearDistance: Float = 0
        var farDistance = maximumDistance

        if direction.x == 0 {
            guard ray.origin.x >= bounds.x, ray.origin.x <= bounds.z else {
                return false
            }
        } else {
            let inverseDirection = 1 / direction.x
            var near = (bounds.x - ray.origin.x) * inverseDirection
            var far = (bounds.z - ray.origin.x) * inverseDirection
            if near > far { swap(&near, &far) }
            nearDistance = max(nearDistance, near)
            farDistance = min(farDistance, far)
            guard nearDistance <= farDistance else { return false }
        }

        if direction.y == 0 {
            guard ray.origin.y >= bounds.y, ray.origin.y <= bounds.w else {
                return false
            }
        } else {
            let inverseDirection = 1 / direction.y
            var near = (bounds.y - ray.origin.y) * inverseDirection
            var far = (bounds.w - ray.origin.y) * inverseDirection
            if near > far { swap(&near, &far) }
            nearDistance = max(nearDistance, near)
            farDistance = min(farDistance, far)
        }

        return nearDistance <= farDistance
    }

    private static func union(
        _ lhs: SIMD4<Float>,
        _ rhs: SIMD4<Float>
    ) -> SIMD4<Float> {
        SIMD4(
            min(lhs.x, rhs.x),
            min(lhs.y, rhs.y),
            max(lhs.z, rhs.z),
            max(lhs.w, rhs.w)
        )
    }

    private static func perimeter(_ bounds: SIMD4<Float>) -> Float {
        2 * ((bounds.z - bounds.x) + (bounds.w - bounds.y))
    }

    /// Exhaustive storage/topology audit used by tests and diagnostics.
    func validateStructure() -> Bool {
        var freeCount = 0
        var freeIndex = freeList
        while freeIndex != Self.nullIndex {
            let index = Int(freeIndex)
            guard index >= 0, index < capacity,
                  nodes[index].height == -1
            else { return false }

            freeCount += 1
            guard freeCount <= capacity else { return false }
            freeIndex = nodes[index].nextFree
        }

        var actualNodeCount = 0
        var actualProxyCount = 0
        var actualBranchCount = 0

        for index in 0..<capacity {
            let node = nodes[index]
            if node.height == -1 { continue }
            actualNodeCount += 1

            if node.isLeaf {
                guard node.height == 0,
                      node.childB == Self.nullIndex
                else { return false }
                actualProxyCount += 1
            } else {
                let childA = Int(node.childA)
                let childB = Int(node.childB)
                guard childA >= 0, childA < capacity,
                      childB >= 0, childB < capacity,
                      childA != childB,
                      nodes[childA].height >= 0,
                      nodes[childB].height >= 0,
                      nodes[childA].parent == Int32(index),
                      nodes[childB].parent == Int32(index),
                      node.bounds == Self.union(
                        nodes[childA].bounds,
                        nodes[childB].bounds
                      ),
                      node.height == 1 + max(
                        nodes[childA].height,
                        nodes[childB].height
                      )
                else { return false }
                actualBranchCount += 1
            }

            var ancestor = Int32(index)
            var stepCount = 0
            while nodes[Int(ancestor)].parent != Self.nullIndex {
                ancestor = nodes[Int(ancestor)].parent
                let ancestorIndex = Int(ancestor)
                guard ancestorIndex >= 0, ancestorIndex < capacity else {
                    return false
                }
                stepCount += 1
                guard stepCount <= actualNodeCount + capacity else {
                    return false
                }
            }
            guard ancestor == root else { return false }
        }

        if root == Self.nullIndex {
            guard actualNodeCount == 0,
                  actualProxyCount == 0,
                  actualBranchCount == 0
            else { return false }
        } else {
            let rootIndex = Int(root)
            guard rootIndex >= 0, rootIndex < capacity,
                  nodes[rootIndex].parent == Self.nullIndex,
                  actualBranchCount == actualProxyCount - 1
            else { return false }
        }

        return actualNodeCount == Int(allocatedNodeCount)
            && actualProxyCount == Int(proxyCount)
            && actualNodeCount + freeCount == capacity
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

        var isLeaf: Bool { childA == DynamicAABBTree2D.nullIndex }

        var rect: Rect {
            Rect(
                x: bounds.x,
                y: bounds.y,
                width: bounds.z - bounds.x,
                height: bounds.w - bounds.y
            )
        }

        static func allocated(generation: UInt32) -> Self {
            Self(
                bounds: .zero,
                parent: DynamicAABBTree2D.nullIndex,
                childA: DynamicAABBTree2D.nullIndex,
                childB: DynamicAABBTree2D.nullIndex,
                height: 0,
                nextFree: DynamicAABBTree2D.nullIndex,
                generation: generation
            )
        }

        static func leaf(bounds: Rect, generation: UInt32) -> Self {
            Self(
                bounds: .init(bounds.minX, bounds.minY, bounds.maxX, bounds.maxY),
                parent: DynamicAABBTree2D.nullIndex,
                childA: DynamicAABBTree2D.nullIndex,
                childB: DynamicAABBTree2D.nullIndex,
                height: 0,
                nextFree: DynamicAABBTree2D.nullIndex,
                generation: generation
            )
        }

        static func branch(
            bounds: SIMD4<Float>,
            parent: Int32,
            childA: Int32,
            childB: Int32,
            height: Int32,
            generation: UInt32
        ) -> Self {
            Self(
                bounds: bounds,
                parent: parent,
                childA: childA,
                childB: childB,
                height: height,
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
