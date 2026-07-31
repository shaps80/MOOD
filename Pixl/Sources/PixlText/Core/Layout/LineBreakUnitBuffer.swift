struct LineBreakUnit: Sendable {
    let scalar: UInt32
    let sourceOffset: Int
    let raw: UnicodeLineBreakProperty
    let resolved: UnicodeLineBreakProperty
    let isAttached: Bool
    let isEastAsian: Bool
    let isInitialPunctuation: Bool
    let isFinalPunctuation: Bool
    let isExtendedPictographic: Bool
}

struct LineBreakUnitBuffer: ~Copyable {
    private var storage: UnsafeMutablePointer<LineBreakUnit>?
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

    subscript(index: Int) -> LineBreakUnit {
        precondition(index >= 0 && index < count)
        return storage![index]
    }

    mutating func append(_ unit: consuming LineBreakUnit) {
        ensureCapacity(for: count + 1)
        storage!.advanced(by: count).initialize(to: unit)
        count += 1
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

    private mutating func ensureCapacity(for required: Int) {
        guard required > capacity else { return }
        let newCapacity = max(required, max(16, capacity * 2))
        let newStorage = UnsafeMutablePointer<LineBreakUnit>.allocate(capacity: newCapacity)
        if let storage, count > 0 {
            newStorage.moveInitialize(from: storage, count: count)
            storage.deallocate()
        }
        storage = newStorage
        capacity = newCapacity
    }
}
