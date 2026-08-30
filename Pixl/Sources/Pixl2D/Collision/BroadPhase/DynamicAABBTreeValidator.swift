import Swift

enum DynamicAABBTreeValidator {
    static func validate(
        nodes: UnsafePointer<DynamicAABBTreeNode>,
        capacity: Int,
        freeList: Int32,
        allocatedNodeCount: Int32,
        root: Int32,
        proxyCount: Int32
    ) -> Bool {
        let nullIndex = DynamicAABBTreeNode.nullIndex
        var freeCount = 0
        var freeIndex = freeList
        while freeIndex != nullIndex {
            let index = Int(freeIndex)
            guard index >= 0, index < capacity, nodes[index].height == -1 else {
                return false
            }
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
                guard node.height == 0, node.childB == nullIndex else {
                    return false
                }
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
                      node.bounds == union(nodes[childA].bounds, nodes[childB].bounds),
                      node.height == 1 + max(nodes[childA].height, nodes[childB].height)
                else { return false }
                actualBranchCount += 1
            }

            var ancestor = Int32(index)
            var stepCount = 0
            while nodes[Int(ancestor)].parent != nullIndex {
                ancestor = nodes[Int(ancestor)].parent
                let ancestorIndex = Int(ancestor)
                guard ancestorIndex >= 0, ancestorIndex < capacity else {
                    return false
                }
                stepCount += 1
                guard stepCount <= capacity else { return false }
            }
            guard ancestor == root else { return false }
        }

        if root == nullIndex {
            guard actualNodeCount == 0,
                  actualProxyCount == 0,
                  actualBranchCount == 0
            else { return false }
        } else {
            let rootIndex = Int(root)
            guard rootIndex >= 0, rootIndex < capacity,
                  nodes[rootIndex].parent == nullIndex,
                  actualBranchCount == actualProxyCount - 1
            else { return false }
        }

        return actualNodeCount == Int(allocatedNodeCount)
            && actualProxyCount == Int(proxyCount)
            && actualNodeCount + freeCount == capacity
    }

    private static func union(
        _ lhs: SIMD4<Float>,
        _ rhs: SIMD4<Float>
    ) -> SIMD4<Float> {
        .init(
            min(lhs.x, rhs.x),
            min(lhs.y, rhs.y),
            max(lhs.z, rhs.z),
            max(lhs.w, rhs.w)
        )
    }
}
