import Swift

/// Fixed-capacity, generational storage for backend resources.
///
/// `ResourcePool` performs no allocation after initialization. It is intentionally
/// single-owner: callers must provide any synchronization required when sharing a
/// pool across threads.
package final class ResourcePool<Value> {
    private struct Slot {
        var generation: UInt32
        var state: UInt32
    }

    private static var noSlot: UInt32 { .max }
    private static var occupied: UInt32 { .max - 1 }
    private static var retired: UInt32 { .max - 2 }

    private let slots: UnsafeMutablePointer<Slot>
    private let values: UnsafeMutablePointer<Value>

    package let capacity: UInt32
    package private(set) var count: UInt32 = 0

    private var nextUnused: UInt32 = 0
    private var freeHead: UInt32 = noSlot

    package init(capacity: UInt32) {
        precondition(capacity > 0, "ResourcePool capacity must be greater than zero")
        precondition(capacity < Self.retired, "ResourcePool capacity exceeds its index space")

        self.capacity = capacity
        slots = .allocate(capacity: Int(capacity))
        values = .allocate(capacity: Int(capacity))

        slots.initialize(
            repeating: Slot(generation: 1, state: Self.noSlot),
            count: Int(capacity)
        )
    }

    deinit {
        for index in 0..<nextUnused where slots[Int(index)].state == Self.occupied {
            values.advanced(by: Int(index)).deinitialize(count: 1)
        }

        slots.deinitialize(count: Int(capacity))
        slots.deallocate()
        values.deallocate()
    }

    /// Inserts a value without allocating. Returns `nil` when no slot remains.
    package func insert(_ value: consuming Value) -> ResourceID? {
        let index: UInt32

        if freeHead != Self.noSlot {
            index = freeHead
            freeHead = slots[Int(index)].state
        } else {
            guard nextUnused < capacity else { return nil }
            index = nextUnused
            nextUnused += 1
        }

        let generation = slots[Int(index)].generation
        slots[Int(index)].state = Self.occupied
        values.advanced(by: Int(index)).initialize(to: value)
        count += 1

        return ResourceID(index: index, generation: generation)
    }

    /// Provides scoped, read-only access without copying the stored value.
    package func withValue<Result>(
        for id: ResourceID,
        _ body: (UnsafePointer<Value>) throws -> Result
    ) rethrows -> Result? {
        guard contains(id) else { return nil }
        return try body(UnsafePointer(values.advanced(by: Int(id.index))))
    }

    /// Provides scoped, mutable access without copying the stored value.
    package func update<Result>(
        _ id: ResourceID,
        _ body: (UnsafeMutablePointer<Value>) throws -> Result
    ) rethrows -> Result? {
        guard contains(id) else { return nil }
        return try body(values.advanced(by: Int(id.index)))
    }

    /// Removes a live value and makes its slot available for reuse.
    @discardableResult
    package func remove(_ id: ResourceID) -> Bool {
        guard contains(id) else { return false }

        let index = id.index
        let slot = slots.advanced(by: Int(index))

        values.advanced(by: Int(index)).deinitialize(count: 1)
        count -= 1

        // Never wrap a generation: doing so could make an ancient handle valid.
        if slot.pointee.generation == .max {
            slot.pointee.state = Self.retired
        } else {
            slot.pointee.generation += 1
            slot.pointee.state = freeHead
            freeHead = index
        }

        return true
    }

    package func contains(_ id: ResourceID) -> Bool {
        guard id.index < nextUnused else { return false }

        let slot = slots[Int(id.index)]
        return slot.state == Self.occupied && slot.generation == id.generation
    }

    /// Removes every value selected by `body` without allocating temporary
    /// storage. The body may dispose backend state before the slot is retired.
    package func removeAll(
        where body: (UnsafeMutablePointer<Value>) -> Bool
    ) {
        var index: UInt32 = 0
        while index < nextUnused {
            defer { index += 1 }
            guard slots[Int(index)].state == Self.occupied else { continue }

            let value = values.advanced(by: Int(index))
            guard body(value) else { continue }

            _ = remove(
                ResourceID(
                    index: index,
                    generation: slots[Int(index)].generation
                )
            )
        }
    }
}
