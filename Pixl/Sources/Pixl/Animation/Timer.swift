import Swift

/// A finite manually advanced timer.
public struct Timer {
    /// Total timer duration in seconds.
    public let duration: Double
    /// Accumulated time clamped to ``duration``.
    public private(set) var elapsed: Double = .zero

    /// Creates a timer at zero elapsed time.
    /// - Parameter duration: Nonnegative total duration in seconds.
    public init(duration: Double) {
        assert(duration >= 0)
        self.duration = duration
    }

    /// Completion fraction clamped to `0...1`.
    public var progress: Double {
        duration == 0 ? 1 : min(elapsed / duration, 1)
    }

    /// Whether elapsed time has reached the duration.
    public var isFinished: Bool {
        elapsed >= duration
    }

    /// Advances elapsed time without exceeding the duration.
    /// - Parameter delta: Time interval in seconds to add.
    public mutating func advance(by delta: Double) {
        elapsed = min(elapsed + delta, duration)
    }

    /// Resets elapsed time to zero.
    public mutating func invalidate() {
        elapsed = 0
    }
}
