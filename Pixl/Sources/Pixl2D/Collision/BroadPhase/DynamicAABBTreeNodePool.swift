struct DynamicAABBTreeNodePool: ~Copyable {
    private(set) var nodes: UnsafeMutablePointer<DynamicAABBTreeNode>
    private(set) var capacity: Int
    private(set) var allocatedNodeCount: Int32 = 0
    private(set) var freeList: Int32

    init(proxyCapacity: Int) {
        capacity = max(proxyCapacity, 16) * 2 - 1
        nodes = .allocate(capacity: capacity)
        freeList = 0

        for index in 0..<capacity {
            let next = index + 1 < capacity
                ? Int32(index + 1)
                : DynamicAABBTreeNode.nullIndex
            nodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }
    }

    deinit {
        nodes.deinitialize(count: capacity)
        nodes.deallocate()
    }

    mutating func allocateNode() -> Int32 {
        if freeList == DynamicAABBTreeNode.nullIndex { grow() }

        let index = freeList
        let generation = nodes[Int(index)].generation
        freeList = nodes[Int(index)].nextFree
        nodes[Int(index)] = .allocated(generation: generation)
        allocatedNodeCount += 1
        return index
    }

    mutating func freeNode(_ index: Int32) {
        let generation = nodes[Int(index)].generation &+ 1
        nodes[Int(index)] = .free(next: freeList, generation: generation)
        freeList = index
        allocatedNodeCount -= 1
    }

    private mutating func grow() {
        let oldCapacity = capacity
        let newCapacity = oldCapacity + max(oldCapacity / 2, 1)
        let newNodes = UnsafeMutablePointer<DynamicAABBTreeNode>.allocate(
            capacity: newCapacity
        )
        newNodes.moveInitialize(from: nodes, count: oldCapacity)
        nodes.deallocate()

        for index in oldCapacity..<newCapacity {
            let next = index + 1 < newCapacity
                ? Int32(index + 1)
                : DynamicAABBTreeNode.nullIndex
            newNodes.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }

        nodes = newNodes
        capacity = newCapacity
        freeList = Int32(oldCapacity)
    }
}
