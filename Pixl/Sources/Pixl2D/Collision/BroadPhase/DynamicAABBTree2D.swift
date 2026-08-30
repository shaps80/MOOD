import Swift

/// A balanced, allocation-free-in-steady-state broad-phase index for 2D bounds.
package final class DynamicAABBTree2D {
    /// Controls traversal after one broad-phase ray candidate is visited.
    enum RayCastAction: Sendable {
        /// Continue without shortening the ray.
        case ignore
        /// Continue while pruning candidates beyond this distance.
        case clip(to: Float)
        /// Stop traversal immediately.
        case terminate
    }

    private static let initialProxyCapacity = 16
    private static let nullIndex = DynamicAABBTreeNode.nullIndex

    private var pool: DynamicAABBTreeNodePool
    private var proxyCount: Int32 = 0
    private var root: Int32 = nullIndex

    @inline(__always)
    private var nodes: UnsafeMutablePointer<DynamicAABBTreeNode> {
        pool.nodes
    }

    var count: Int { Int(proxyCount) }

    /// Current tree height. An empty tree has height zero.
    var height: Int {
        root == Self.nullIndex ? 0 : Int(nodes[Int(root)].height)
    }

    init() {
        pool = .init(proxyCapacity: Self.initialProxyCapacity)
    }

    func insert(
        _ bounds: Rect,
        userData: Int32 = DynamicAABBTreeNode.nullIndex
    ) -> ProxyID {
        let leaf = pool.allocateNode()
        let generation = nodes[Int(leaf)].generation
        nodes[Int(leaf)] = .leaf(
            bounds: bounds,
            generation: generation,
            userData: userData
        )
        insertLeaf(leaf)
        proxyCount += 1
        return ProxyID(index: leaf, generation: generation)
    }

    func remove(_ proxy: ProxyID) {
        guard let leaf = liveIndex(for: proxy) else { return }
        removeLeaf(Int32(leaf))
        pool.freeNode(Int32(leaf))
        proxyCount -= 1
    }

    /// Returns the broad-phase AABB stored for a live proxy.
    func bounds(for proxy: ProxyID) -> Rect? {
        guard let index = liveIndex(for: proxy) else { return nil }
        return nodes[index].rect
    }

    /// Moves a proxy by removing and reinserting it with new broad-phase bounds.
    @discardableResult
    func move(_ proxy: ProxyID, to bounds: Rect) -> Bool {
        guard let leaf = liveIndex(for: proxy) else { return false }
        removeLeaf(Int32(leaf))
        nodes[leaf].bounds = Self.packed(bounds)
        insertLeaf(Int32(leaf))
        return true
    }

    /// Enlarges a proxy and its ancestors without reinserting it.
    @discardableResult
    func enlarge(_ proxy: ProxyID, toInclude bounds: Rect) -> Bool {
        guard let leaf = liveIndex(for: proxy) else { return false }
        let enlarged = Self.union(nodes[leaf].bounds, Self.packed(bounds))
        guard enlarged != nodes[leaf].bounds else { return false }
        nodes[leaf].bounds = enlarged

        var index = nodes[leaf].parent
        while index != Self.nullIndex {
            let childA = nodes[Int(index)].childA
            let childB = nodes[Int(index)].childB
            let combined = Self.union(
                nodes[Int(childA)].bounds,
                nodes[Int(childB)].bounds
            )
            guard combined != nodes[Int(index)].bounds else { break }
            nodes[Int(index)].bounds = combined
            index = nodes[Int(index)].parent
        }
        return true
    }

    /// Visits every broad-phase proxy whose AABB overlaps `bounds`.
    @discardableResult
    func query(
        overlapping bounds: Rect,
        _ visit: (ProxyID, Int32) -> Bool
    ) -> TreeQueryStats2D {
        guard root != Self.nullIndex else { return .init() }

        let queryBounds = Self.packed(bounds)
        var stats = TreeQueryStats2D()
        var previous = Self.nullIndex
        var current = root

        while current != Self.nullIndex {
            let node = nodes[Int(current)]
            let next: Int32

            if previous == node.parent {
                stats.nodeVisits += 1
                if !Self.overlaps(node.bounds, queryBounds) {
                    next = node.parent
                } else if node.isLeaf {
                    stats.leafVisits += 1
                    let shouldContinue = visit(
                        .init(index: current, generation: node.generation),
                        node.userData
                    )
                    if !shouldContinue { return stats }
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

        return stats
    }

    /// Visits broad-phase ray candidates and lets exact shape tests clip traversal.
    @discardableResult
    func rayCast(
        _ ray: Ray2D,
        maximumDistance: Float = .infinity,
        _ visit: (ProxyID, Int32, Float) -> RayCastAction
    ) -> TreeQueryStats2D {
        let direction = ray.normalizedDirection
        guard root != Self.nullIndex,
              ray.origin.isValid,
              direction != .zero,
              maximumDistance >= 0
        else { return .init() }

        var clippedDistance = maximumDistance
        var stats = TreeQueryStats2D()
        var previous = Self.nullIndex
        var current = root

        while current != Self.nullIndex {
            let node = nodes[Int(current)]
            let next: Int32

            if previous == node.parent {
                stats.nodeVisits += 1
                if !rayIntersects(
                    node.bounds,
                    ray: ray,
                    maximumDistance: clippedDistance
                ) {
                    next = node.parent
                } else if node.isLeaf {
                    stats.leafVisits += 1
                    let proxy = ProxyID(
                        index: current,
                        generation: node.generation
                    )
                    switch visit(proxy, node.userData, clippedDistance) {
                    case .ignore:
                        break
                    case .clip(let distance):
                        if distance >= 0, distance < clippedDistance {
                            clippedDistance = distance
                        }
                    case .terminate:
                        return stats
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

        return stats
    }

    private func liveIndex(for proxy: ProxyID) -> Int? {
        let index = Int(proxy.index)
        guard index >= 0, index < pool.capacity else { return nil }
        let node = nodes[index]
        guard node.height == 0, node.generation == proxy.generation else {
            return nil
        }
        return index
    }

    private func insertLeaf(_ leaf: Int32) {
        if root == Self.nullIndex {
            root = leaf
            nodes[Int(leaf)].parent = Self.nullIndex
            return
        }

        let sibling = bestSibling(for: nodes[Int(leaf)].bounds)
        let oldParent = nodes[Int(sibling)].parent
        let newParent = pool.allocateNode()
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
            pool.freeNode(parent)
            return
        }

        if nodes[Int(grandParent)].childA == parent {
            nodes[Int(grandParent)].childA = sibling
        } else {
            nodes[Int(grandParent)].childB = sibling
        }
        nodes[Int(sibling)].parent = grandParent
        pool.freeNode(parent)

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

    private static func packed(_ bounds: Rect) -> SIMD4<Float> {
        .init(bounds.minX, bounds.minY, bounds.maxX, bounds.maxY)
    }

    private static func overlaps(
        _ lhs: SIMD4<Float>,
        _ rhs: SIMD4<Float>
    ) -> Bool {
        lhs.x <= rhs.z
            && lhs.z >= rhs.x
            && lhs.y <= rhs.w
            && lhs.w >= rhs.y
    }

    /// Exhaustive storage/topology audit used by tests and diagnostics.
    func validateStructure() -> Bool {
        DynamicAABBTreeValidator.validate(
            nodes: nodes,
            capacity: pool.capacity,
            freeList: pool.freeList,
            allocatedNodeCount: pool.allocatedNodeCount,
            root: root,
            proxyCount: proxyCount
        )
    }
}
