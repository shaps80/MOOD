struct ColliderRecordPool2D: ~Copyable {
    private(set) var records: UnsafeMutablePointer<ColliderRecord2D>
    private(set) var capacity: Int
    private(set) var count = 0
    private var freeList: Int32 = 0

    init(capacity: Int = 16) {
        self.capacity = max(capacity, 16)
        records = .allocate(capacity: self.capacity)
        initializeFreeRecords(from: 0, to: self.capacity)
    }

    deinit {
        records.deinitialize(count: capacity)
        records.deallocate()
    }

    mutating func allocate(
        bounds: Rect,
        broadBounds: Rect,
        isDynamic: Bool
    ) -> ColliderID {
        if freeList == -1 { grow() }
        let index = freeList
        let generation = records[Int(index)].generation
        freeList = records[Int(index)].nextFree
        records[Int(index)] = .live(
            bounds: bounds,
            broadBounds: broadBounds,
            generation: generation,
            isDynamic: isDynamic
        )
        count += 1
        return .init(index: index, generation: generation)
    }

    mutating func free(_ id: ColliderID) {
        let index = Int(id.index)
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
        newRecords.moveInitialize(from: records, count: oldCapacity)
        records.deallocate()
        records = newRecords
        capacity = newCapacity
        freeList = Int32(oldCapacity)
        initializeFreeRecords(from: oldCapacity, to: newCapacity)
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
