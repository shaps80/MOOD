import Synchronization
final class RecordingControl: @unchecked Sendable {
    let value: UnsafeMutablePointer<Atomic<UInt64>>
    init() { value = .allocate(capacity: 1); value.initialize(to: Atomic(0)) }
    deinit { value.deinitialize(count: 1); value.deallocate() }
}
