import Synchronization

/// Bounded multi-producer, single-consumer telemetry storage. Producers make
/// one claim attempt and drop on collision/full storage; they never wait.
nonisolated final class ProfileBuffer<Value: Sendable>: @unchecked Sendable {
    private let capacity: Int
    private let states: UnsafeMutablePointer<Atomic<UInt8>>
    private let entries: UnsafeMutablePointer<(sequence: UInt64, value: Value)?>
    private let nextSequence = Atomic<UInt64>(0)
    private let dropped = Atomic<UInt64>(0)

    init(capacity: Int = 512) {
        precondition(capacity > 0)
        self.capacity = capacity
        states = .allocate(capacity: capacity)
        entries = .allocate(capacity: capacity)
        for index in 0..<capacity {
            states.advanced(by: index).initialize(to: Atomic(0))
        }
        entries.initialize(repeating: nil, count: capacity)
    }

    deinit {
        states.deinitialize(count: capacity)
        states.deallocate()
        entries.deinitialize(count: capacity)
        entries.deallocate()
    }

    var droppedCount: UInt64 { dropped.load(ordering: .relaxed) }

    func record(_ value: Value) {
        let sequence = nextSequence.wrappingAdd(1, ordering: .relaxed).oldValue
        let index = Int(sequence % UInt64(capacity))
        // 0 = free, 1 = exclusively owned, 2 = published. Acquire pairs
        // with consumer release before reuse; release publishes the payload.
        guard states[index].compareExchange(
            expected: 0, desired: 1, ordering: .acquiring
        ).exchanged else {
            dropped.wrappingAdd(1, ordering: .relaxed)
            return
        }
        entries[index] = (sequence, value)
        states[index].store(2, ordering: .releasing)
    }

    /// Call from one consumer only. Delivery is unordered; sequence identifies
    /// publication reservations. A producer still writing is skipped this pass.
    func drain(_ consume: (UInt64, Value) -> Void) {
        for index in 0..<capacity {
            guard states[index].compareExchange(
                expected: 2, desired: 1, ordering: .acquiring
            ).exchanged else { continue }
            let entry = entries[index]!
            entries[index] = nil
            states[index].store(0, ordering: .releasing)
            consume(entry.sequence, entry.value)
        }
    }
}
