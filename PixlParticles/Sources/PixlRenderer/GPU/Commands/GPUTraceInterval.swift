/// Calibrated host-uptime seconds, emitted asynchronously after GPU completion.
/// Individual encoder/stage intervals may overlap; never sum to infer frame time.
public struct GPUTraceInterval: Sendable {
    public enum Phase: Sendable { case frame, preparation, diagnostics, vertex, fragment }
    public let phase: Phase
    public let start: Double
    public let end: Double
    public let frameID: UInt64
    public let captureID: UInt64
    public init(phase: Phase, start: Double, end: Double, frameID: UInt64, captureID: UInt64) {
        self.phase = phase; self.start = start; self.end = end
        self.frameID = frameID; self.captureID = captureID
    }
}
