/// Fixed-size CPU stage timing; emitted synchronously on the simulation owner.
public struct SimulationTraceInterval: Sendable {
    public enum Phase: Sendable {
        case clockScheduling, fixedUpdate, sampleResult
        case scheduling, integration, recycling, generation, retirement, allocation, commit
    }
    public let phase: Phase
    public let start: ContinuousClock.Instant
    public let end: ContinuousClock.Instant
    public let frameID: UInt64
    public let captureID: UInt64
}
