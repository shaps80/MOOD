import Synchronization

/// Prebound handle. Keeps its storage alive, including after session teardown.
/// One producer per track unless `concurrent` was requested at setup.
/// No registration, name lookup, heap allocation or retries on this path.
public struct ProfileRecorder: @unchecked Sendable {
    let owner: TrackBuffer
    let controlOwner: RecordingControl
    let state: UnsafeMutablePointer<RecordingState>
    let slots: UnsafeMutablePointer<ProfileEvent>
    let control: UnsafeMutablePointer<Atomic<UInt64>>
    let capacity: UInt64
    let concurrent: Bool

    @inline(__always)
    public func begin(_ scope: ProfileScope, correlation: UInt64 = 0, detail: UInt32 = 0) -> ProfileToken {
        let generation = control.pointee.load(ordering: .acquiring)
        return ProfileToken(start: generation & 1 == 1 ? .now : state.pointee.origin,
                            generation: generation, correlation: correlation,
                            scope: scope.id, detail: detail)
    }

    @inline(__always)
    public func end(_ token: ProfileToken) {
        guard token.generation & 1 == 1,
              control.pointee.load(ordering: .acquiring) == token.generation else { return }
        write(ProfileEvent(start: token.start, end: .now, generation: token.generation,
                           correlation: token.correlation, scope: token.scope, detail: token.detail))
    }

    /// Capture a generation before asynchronous submission; completion must use
    /// that generation so late callbacks cannot enter a subsequent capture.
    public var generation: UInt64 { control.pointee.load(ordering: .acquiring) }

    /// Already-timestamped external work (e.g. GPU). May complete after freezing;
    /// the consumer retains that submission generation and rejects older captures.
    public func record(_ scope: ProfileScope, start: ContinuousClock.Instant,
                       end: ContinuousClock.Instant, generation: UInt64,
                       correlation: UInt64 = 0, detail: UInt32 = 0) {
        guard generation & 1 == 1, end >= start else { return }
        let current = control.pointee.load(ordering: .acquiring)
        guard current == generation || current == generation + 1 else { return }
        write(ProfileEvent(start: start, end: end, generation: generation,
                           correlation: correlation, scope: scope.id, external: true, detail: detail))
    }

    @inline(__always)
    private func write(_ event: ProfileEvent) {
        if concurrent {
            guard state.pointee.writing.compareExchange(expected: false, desired: true,
                ordering: .acquiring).exchanged else {
                state.pointee.dropped.wrappingAdd(1, ordering: .relaxed)
                return
            }
        }
        let head = state.pointee.head.load(ordering: .relaxed)
        let tail = state.pointee.tail.load(ordering: .acquiring)
        if head &- tail < capacity {
            slots[Int(head % capacity)] = event
            state.pointee.head.store(head &+ 1, ordering: .releasing)
        } else {
            state.pointee.dropped.wrappingAdd(1, ordering: .relaxed)
        }
        if concurrent { state.pointee.writing.store(false, ordering: .releasing) }
    }
}
