/// CPU wall-time interval emitted synchronously on the rendering thread.
public struct CPUTraceInterval: Sendable {
    public enum Phase: UInt32, Sendable {
        case frameWait
        case buffers
        case commandBuffer
        case computeEncoding
        case composition
        case drawableWait
        case drawEncoding
        case submission
    }
    public let phase: Phase
    public let start: ContinuousClock.Instant
    public let end: ContinuousClock.Instant
    public let frameID: UInt64
    public let captureID: UInt64
}
