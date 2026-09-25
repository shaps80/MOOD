import Synchronization
struct RecordingState: ~Copyable {
    let head = Atomic<UInt64>(0)
    let tail = Atomic<UInt64>(0)
    let dropped = Atomic<UInt64>(0)
    let writing = Atomic<Bool>(false)
    let origin: ContinuousClock.Instant
    init(origin: ContinuousClock.Instant) { self.origin = origin }
}
