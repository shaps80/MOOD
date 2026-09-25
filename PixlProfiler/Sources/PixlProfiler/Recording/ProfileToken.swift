/// Plain value; no strings, closures or reference-counted payloads.
public struct ProfileToken: Sendable {
    let start: ContinuousClock.Instant
    let generation: UInt64
    let correlation: UInt64
    let scope: UInt32
    let detail: UInt32
}
