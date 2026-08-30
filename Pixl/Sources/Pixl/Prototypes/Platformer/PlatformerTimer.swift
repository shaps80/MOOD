struct PlatformerTimer: Equatable, Sendable {
    private(set) var remaining: Float = 0

    var isRunning: Bool { remaining > 0 }

    mutating func start(duration: Float) {
        remaining = max(0, duration)
    }

    mutating func stop() {
        remaining = 0
    }

    /// Advances the timer and reports whether it expired during this step.
    mutating func advance(by delta: Float) -> Bool {
        guard remaining > 0 else { return false }
        remaining = max(0, remaining - delta)
        return remaining == 0
    }
}
