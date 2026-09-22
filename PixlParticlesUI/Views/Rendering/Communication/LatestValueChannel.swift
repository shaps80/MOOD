import Synchronization

/// Single-producer/single-consumer latest-value handoff. Each side owns one
/// slot; an atomic exchange transfers the third slot. Neither side waits.
/// Values may contain references, but their mutable contents must retain their
/// own thread ownership. Only the slot payload is transferred by this channel.
nonisolated final class LatestValueChannel<Value>: @unchecked Sendable {
    private let slots: UnsafeMutablePointer<Value?>
    // Low two bits identify the shared slot; bit 2 means unread publication.
    private let middle = Atomic<UInt8>(1)
    private var producerIndex: UInt8 = 0
    private var consumerIndex: UInt8 = 2

    init() {
        slots = .allocate(capacity: 3)
        slots.initialize(repeating: nil, count: 3)
    }

    deinit {
        slots.deinitialize(count: 3)
        slots.deallocate()
    }

    /// Producer only. Replaces pending values without modifying the reader's slot.
    func publish(_ value: Value) {
        slots[Int(producerIndex)] = value
        producerIndex = middle.exchange(
            producerIndex | 4, ordering: .acquiringAndReleasing
        ) & 3
    }

    /// Consumer only. Acquire observes the payload; release returns the old
    /// reader slot to the producer after all reads/copies from it have finished.
    func take() -> Value? {
        guard middle.load(ordering: .acquiring) & 4 != 0 else { return nil }
        consumerIndex = middle.exchange(
            consumerIndex, ordering: .acquiringAndReleasing
        ) & 3
        return slots[Int(consumerIndex)]
    }
}
