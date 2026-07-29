struct GlyphBuffer: ~Copyable {
    private var storage: UnsafeMutablePointer<ShapingGlyph>?
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

    subscript(index: Int) -> ShapingGlyph {
        get {
            precondition(index >= 0 && index < count)
            return storage![index]
        }
        set {
            precondition(index >= 0 && index < count)
            storage![index] = newValue
        }
    }

    mutating func append(_ glyph: consuming ShapingGlyph) {
        ensureCapacity(for: count + 1)
        storage!.advanced(by: count).initialize(to: glyph)
        count += 1
    }

    mutating func removeLast(_ amount: Int) {
        precondition(amount >= 0 && amount <= count)
        guard amount > 0 else { return }
        storage!.advanced(by: count - amount).deinitialize(count: amount)
        count -= amount
    }

    private mutating func ensureCapacity(for required: Int) {
        guard required > capacity else { return }
        let newCapacity = max(required, max(8, capacity * 2))
        let newStorage = UnsafeMutablePointer<ShapingGlyph>.allocate(capacity: newCapacity)
        if let storage, count > 0 {
            newStorage.moveInitialize(from: storage, count: count)
            storage.deallocate()
        }
        storage = newStorage
        capacity = newCapacity
    }
}
