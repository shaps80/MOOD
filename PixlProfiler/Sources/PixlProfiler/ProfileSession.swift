import Synchronization

/// Setup/control/consume have ONE owner. Recording handles may be used on their
/// assigned threads concurrently. No thread, framework or UI dependency in core.
/// Finish setup before starting any producers. Never destroy with writes in flight.
public final class ProfileSession: @unchecked Sendable {
    let origin = ContinuousClock.now
    let controlOwner = RecordingControl()
    var control: UnsafeMutablePointer<Atomic<UInt64>> { controlOwner.value }
    var buffers: [TrackBuffer] = []
    let scopes: [ProfileSnapshot.Scope]
    var started = false
    private var trackNames: [UInt32: String] = [:]
    private var trackInstances: [UInt32: Set<Int>] = [:]
    var cutoff: ContinuousClock.Instant?
    var history: [(Int, ProfileEvent)] = []
    var generation: UInt64 = 0
    var dropBaseline: UInt64 = 0
    let retention: Double
    let maximumEvents: Int
    var retainedOut = 0

    public init(scopes: [ProfileScope], retention: Double = 3, maximumEvents: Int = 100_000) {
        precondition(retention > 0 && maximumEvents > 0)
        precondition(Set(scopes.map(\.id)).count == scopes.count, "Duplicate scope ID")
        self.scopes = scopes.map { .init(id: $0.id, name: String(describing: $0.name), kind: $0.kind, parentScope: $0.parentScope) }
        self.retention = retention; self.maximumEvents = maximumEvents
        history.reserveCapacity(maximumEvents)
    }

    /// Setup only. `instance` is a predeclared pool member, never a hot-path name.
    public func prepare(_ track: ProfileTrack, instance: Int? = nil,
                        capacity: Int = 16_384, concurrent: Bool = false) -> ProfileRecorder {
        precondition(!started, "Prepare every track before capture starts")
        precondition(capacity > 0)
        precondition(instance.map { $0 >= 0 } ?? true)
        let baseName = String(describing: track.name)
        precondition(trackNames[track.id].map { $0 == baseName } ?? true, "Track ID has conflicting definitions")
        let inserted = trackInstances[track.id, default: []].insert(instance ?? -1).inserted
        precondition(inserted, "Duplicate track instance")
        trackNames[track.id] = baseName
        let name = baseName + (instance.map { " \($0)" } ?? "")
        let buffer = TrackBuffer(definition: .init(id: buffers.count, definitionID: track.id, instance: instance, name: name),
                                 capacity: capacity, concurrent: concurrent, origin: origin)
        buffers.append(buffer)
        return ProfileRecorder(owner: buffer, controlOwner: controlOwner, state: buffer.state, slots: buffer.entries, control: control,
                               capacity: UInt64(capacity), concurrent: concurrent)
    }

    public func resume() {
        guard control.pointee.load(ordering: .acquiring) & 1 == 0 else { return }
        started = true
        for buffer in buffers { buffer.drain { _ in } }
        generation = (generation &+ 2) | 1
        history.removeAll(keepingCapacity: true); cutoff = nil; retainedOut = 0
        dropBaseline = totalDropped
        control.pointee.store(generation, ordering: .releasing)
    }
    public func freeze() {
        guard control.pointee.load(ordering: .acquiring) & 1 == 1 else { return }
        cutoff = .now
        control.pointee.store(generation + 1, ordering: .releasing)
    }
    var totalDropped: UInt64 {
        buffers.reduce(0) { $0 &+ $1.state.pointee.dropped.load(ordering: .relaxed) }
    }
    func seconds(_ instant: ContinuousClock.Instant) -> Double {
        let value = origin.duration(to: instant).components
        return Double(value.seconds) + Double(value.attoseconds) / 1e18
    }
}
