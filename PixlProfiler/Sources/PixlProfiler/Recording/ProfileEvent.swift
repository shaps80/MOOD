struct ProfileEvent: Sendable {
    var start: ContinuousClock.Instant = .now
    var end: ContinuousClock.Instant = .now
    var generation: UInt64 = 0
    var correlation: UInt64 = 0
    var scope: UInt32 = 0
    var external = false
    var detail: UInt32 = 0
}
