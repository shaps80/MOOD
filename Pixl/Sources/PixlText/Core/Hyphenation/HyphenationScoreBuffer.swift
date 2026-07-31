struct HyphenationScoreBuffer: ~Copyable {
    private var storage: UnsafeMutablePointer<UInt8>?
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

    subscript(index: Int) -> UInt8 {
        get {
            precondition(index >= 0 && index < count)
            return storage![index]
        }
        set {
            precondition(index >= 0 && index < count)
            storage![index] = newValue
        }
    }

    mutating func prepare(count required: Int) {
        precondition(required >= 0)
        if required > capacity {
            storage?.deinitialize(count: count)
            storage?.deallocate()
            capacity = max(required, max(32, capacity * 2))
            storage = .allocate(capacity: capacity)
            count = 0
        } else {
            storage?.deinitialize(count: count)
            count = 0
        }
        storage?.initialize(repeating: 0, count: required)
        count = required
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
}
