final class CollisionContactBuffer2D {
    private(set) var records: UnsafeMutablePointer<CollisionContactRecord2D>
    private(set) var count = 0
    private var capacity: Int

    init(capacity: Int = 16) {
        self.capacity = max(capacity, 16)
        records = .allocate(capacity: self.capacity)
    }

    deinit {
        records.deinitialize(count: count)
        records.deallocate()
    }

    func reset() {
        records.deinitialize(count: count)
        count = 0
    }

    func append(_ record: CollisionContactRecord2D) {
        if count == capacity { grow() }
        records.advanced(by: count).initialize(to: record)
        count += 1
    }

    func sort() {
        guard count > 1 else { return }

        var start = count / 2
        while start > 0 {
            start -= 1
            siftDown(from: start, through: count - 1)
        }

        var end = count - 1
        while end > 0 {
            swapRecords(0, end)
            end -= 1
            siftDown(from: 0, through: end)
        }
    }

    func swapStorage(with other: CollisionContactBuffer2D) {
        let oldRecords = records
        let oldCount = count
        let oldCapacity = capacity
        records = other.records
        count = other.count
        capacity = other.capacity
        other.records = oldRecords
        other.count = oldCount
        other.capacity = oldCapacity
    }

    private func siftDown(from root: Int, through end: Int) {
        var root = root
        while true {
            let left = root * 2 + 1
            guard left <= end else { return }
            var candidate = root
            if records[candidate] < records[left] { candidate = left }
            let right = left + 1
            if right <= end, records[candidate] < records[right] {
                candidate = right
            }
            guard candidate != root else { return }
            swapRecords(root, candidate)
            root = candidate
        }
    }

    private func grow() {
        let newCapacity = capacity + max(capacity / 2, 1)
        let newRecords = UnsafeMutablePointer<CollisionContactRecord2D>.allocate(
            capacity: newCapacity
        )
        newRecords.moveInitialize(from: records, count: count)
        records.deallocate()
        records = newRecords
        capacity = newCapacity
    }

    @inline(__always)
    private func swapRecords(_ lhs: Int, _ rhs: Int) {
        let value = records[lhs]
        records[lhs] = records[rhs]
        records[rhs] = value
    }
}
