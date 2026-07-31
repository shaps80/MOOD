struct PositionedInsertionBuffer: ~Copyable {
    private var storage: UnsafeMutablePointer<PositionedInsertion>?
    private(set) var count: Int
    private(set) var capacity: Int

    init(minimumCapacity: Int = 0) {
        precondition(minimumCapacity >= 0)
        storage = minimumCapacity == 0 ? nil : .allocate(capacity: minimumCapacity)
        count = 0
        capacity = minimumCapacity
    }

    deinit {
        storage?.deinitialize(count: count)
        storage?.deallocate()
    }

    subscript(index: Int) -> PositionedInsertion {
        precondition(index >= 0 && index < count)
        return storage![index]
    }

    mutating func append(_ insertion: consuming PositionedInsertion) {
        ensureCapacity(for: count + 1)
        storage!.advanced(by: count).initialize(to: insertion)
        count += 1
    }

    mutating func removeLast(_ amount: Int) {
        precondition(amount >= 0 && amount <= count)
        guard amount > 0 else { return }
        storage!.advanced(by: count - amount).deinitialize(count: amount)
        count -= amount
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        storage?.deinitialize(count: count)
        count = 0
        if !keepingCapacity {
            storage?.deallocate()
            storage = nil
            capacity = 0
        }
    }

    func withSpan<Result: ~Copyable>(
        _ body: (Span<PositionedInsertion>) throws -> Result
    ) rethrows -> Result {
        let buffer = UnsafeBufferPointer(start: storage, count: count)
        return try body(unsafe Span(_unsafeElements: buffer))
    }

    private mutating func ensureCapacity(for required: Int) {
        guard required > capacity else { return }
        let newCapacity = max(required, max(8, capacity * 2))
        let newStorage = UnsafeMutablePointer<PositionedInsertion>.allocate(capacity: newCapacity)
        if let storage, count > 0 {
            newStorage.moveInitialize(from: storage, count: count)
            storage.deallocate()
        }
        storage = newStorage
        capacity = newCapacity
    }
}
