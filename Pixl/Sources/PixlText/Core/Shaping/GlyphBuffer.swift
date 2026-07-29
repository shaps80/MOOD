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

    mutating func removeAll(keepingCapacity: Bool = true) {
        storage?.deinitialize(count: count)
        count = 0
        if !keepingCapacity {
            storage?.deallocate()
            storage = nil
            capacity = 0
        }
    }

    mutating func replace(
        _ range: Range<Int>,
        with ids: [UInt16],
        from outputRange: Range<Int>,
        sourceRange: Range<Int>,
        lookupIndex: Int,
        feature: UInt32
    ) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count)
        precondition(outputRange.lowerBound >= 0 && outputRange.upperBound <= ids.count)
        replace(range, replacementCount: outputRange.count) { outputIndex in
            .init(
                id: .init(rawValue: ids[outputRange.lowerBound + outputIndex]),
                sourceRange: sourceRange,
                lookupIndex: lookupIndex,
                feature: feature
            )
        }
    }

    mutating func replace(
        _ range: Range<Int>,
        with id: UInt16,
        sourceRange: Range<Int>,
        lookupIndex: Int,
        feature: UInt32
    ) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count)
        replace(range, replacementCount: 1) { _ in
            .init(
                id: .init(rawValue: id),
                sourceRange: sourceRange,
                lookupIndex: lookupIndex,
                feature: feature
            )
        }
    }

    private mutating func replace(
        _ range: Range<Int>,
        replacementCount: Int,
        makeGlyph: (Int) -> ShapingGlyph
    ) {
        let removedCount = range.count
        let delta = replacementCount - removedCount

        if delta > 0 {
            ensureCapacity(for: count + delta)
            if range.upperBound < count {
                for source in stride(from: count - 1, through: range.upperBound, by: -1) {
                    storage!.advanced(by: source + delta).initialize(
                        to: storage!.advanced(by: source).move()
                    )
                }
            }
        } else if delta < 0 {
            storage!.advanced(by: range.lowerBound).deinitialize(count: removedCount)
            if range.upperBound < count {
                for source in range.upperBound..<count {
                    storage!.advanced(by: source + delta).initialize(
                        to: storage!.advanced(by: source).move()
                    )
                }
            }
        } else {
            storage!.advanced(by: range.lowerBound).deinitialize(count: removedCount)
        }

        if delta > 0 {
            storage!.advanced(by: range.lowerBound).deinitialize(count: removedCount)
        }
        for outputIndex in 0..<replacementCount {
            storage!.advanced(by: range.lowerBound + outputIndex).initialize(
                to: makeGlyph(outputIndex)
            )
        }
        count += delta
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
