/// Optional sink configured outside the update loop; no profiler dependency.
struct SimulationTrace {
    var handler: (@Sendable (SimulationTraceInterval) -> Void)?
    var captureID: UInt64?
    var frameID: UInt64 = 0
    private var start: ContinuousClock.Instant?

    mutating func begin() {
        start = captureID != nil && handler != nil ? .now : nil
    }
    mutating func finish(_ phase: SimulationTraceInterval.Phase) {
        guard let start, let captureID else { return }
        let end = ContinuousClock.now
        handler?(.init(phase: phase, start: start, end: end,
                       frameID: frameID, captureID: captureID))
        self.start = end
    }
}
