import Synchronization
final class TrackBuffer: @unchecked Sendable {
    let state: UnsafeMutablePointer<RecordingState>
    let entries: UnsafeMutablePointer<ProfileEvent>
    let capacity: Int
    let definition: ProfileSnapshot.Track
    let concurrent: Bool
    init(definition: ProfileSnapshot.Track, capacity: Int, concurrent: Bool, origin: ContinuousClock.Instant) {
        self.definition = definition; self.capacity = capacity; self.concurrent = concurrent
        state = .allocate(capacity: 1)
        state.initialize(to: RecordingState(origin: origin))
        entries = .allocate(capacity: capacity)
        entries.initialize(repeating: ProfileEvent(start: origin, end: origin), count: capacity)
    }
    deinit {
        state.deinitialize(count: 1); state.deallocate()
        entries.deinitialize(count: capacity); entries.deallocate()
    }
    func drain(_ consume: (ProfileEvent) -> Void) {
        var tail = state.pointee.tail.load(ordering: .relaxed)
        let head = state.pointee.head.load(ordering: .acquiring)
        while tail != head {
            consume(entries[Int(tail % UInt64(capacity))])
            tail &+= 1
        }
        state.pointee.tail.store(tail, ordering: .releasing)
    }
}
