struct ColliderRecordPool2D: ~Copyable {
    private(set) var records: UnsafeMutablePointer<ColliderRecord2D>
    private(set) var dynamicIndices: UnsafeMutablePointer<Int32>
    private(set) var capacity: Int
    private(set) var count = 0
    private(set) var dynamicCount = 0
    private var freeList: Int32 = 0

    init(capacity: Int = 16) {
        self.capacity = max(capacity, 16)
        records = .allocate(capacity: self.capacity)
        dynamicIndices = .allocate(capacity: self.capacity)
        initializeFreeRecords(from: 0, to: self.capacity)
    }

    deinit {
        records.deinitialize(count: capacity)
        records.deallocate()
        dynamicIndices.deinitialize(count: dynamicCount)
        dynamicIndices.deallocate()
    }

    mutating func allocate(
        geometry: ColliderGeometry2D,
        bounds: Rect,
        broadBounds: Rect,
        layerBit: UInt64,
        mask: CollisionMask,
        isDynamic: Bool
    ) -> ColliderID {
        if freeList == -1 { grow() }
        let index = freeList
        let generation = records[Int(index)].generation
        freeList = records[Int(index)].nextFree
        records[Int(index)] = .live(
            geometry: geometry,
            bounds: bounds,
            broadBounds: broadBounds,
            generation: generation,
            layerBit: layerBit,
            mask: mask,
            isDynamic: isDynamic
        )
        if isDynamic {
            dynamicIndices.advanced(by: dynamicCount).initialize(to: index)
            records[Int(index)].dynamicSlot = Int32(dynamicCount)
            dynamicCount += 1
        }
        count += 1
        return .init(index: index, generation: generation)
    }

    mutating func free(_ id: ColliderID) {
        let index = Int(id.index)
        if records[index].isDynamic {
            removeDynamic(at: records[index].dynamicSlot)
        }
        let generation = records[index].generation &+ 1
        records[index] = .free(next: freeList, generation: generation)
        freeList = id.index
        count -= 1
    }

    func liveIndex(for id: ColliderID) -> Int? {
        let index = Int(id.index)
        guard index >= 0, index < capacity else { return nil }
        let record = records[index]
        guard record.isLive, record.generation == id.generation else {
            return nil
        }
        return index
    }

    func liveID(at index: Int32) -> ColliderID? {
        let value = Int(index)
        guard value >= 0, value < capacity, records[value].isLive else {
            return nil
        }
        return .init(index: index, generation: records[value].generation)
    }

    private mutating func grow() {
        let oldCapacity = capacity
        let newCapacity = oldCapacity + max(oldCapacity / 2, 1)
        let newRecords = UnsafeMutablePointer<ColliderRecord2D>.allocate(
            capacity: newCapacity
        )
        let newDynamicIndices = UnsafeMutablePointer<Int32>.allocate(
            capacity: newCapacity
        )
        newRecords.moveInitialize(from: records, count: oldCapacity)
        newDynamicIndices.moveInitialize(
            from: dynamicIndices,
            count: dynamicCount
        )
        records.deallocate()
        dynamicIndices.deallocate()
        records = newRecords
        dynamicIndices = newDynamicIndices
        capacity = newCapacity
        freeList = Int32(oldCapacity)
        initializeFreeRecords(from: oldCapacity, to: newCapacity)
    }

    private mutating func removeDynamic(at slot: Int32) {
        let slot = Int(slot)
        let lastSlot = dynamicCount - 1
        let movedIndex = dynamicIndices[lastSlot]
        dynamicIndices[slot] = movedIndex
        records[Int(movedIndex)].dynamicSlot = Int32(slot)
        dynamicIndices.advanced(by: lastSlot).deinitialize(count: 1)
        dynamicCount = lastSlot
    }

    private func initializeFreeRecords(from start: Int, to end: Int) {
        for index in start..<end {
            let next = index + 1 < end ? Int32(index + 1) : -1
            records.advanced(by: index).initialize(
                to: .free(next: next, generation: 0)
            )
        }
    }
}
