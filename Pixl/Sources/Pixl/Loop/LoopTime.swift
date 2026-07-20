import Swift

/// Timing supplied to one fixed-rate simulation tick.
public struct FixedTime: Hashable, Sendable {
    /// Zero-based fixed tick number since startup.
    public let tickIndex: UInt64
    /// Fixed scaled simulation interval in seconds.
    public let delta: Double
    /// Total scaled fixed-simulation time in seconds.
    public let elapsedSeconds: Double

    init(
        tickIndex: UInt64,
        delta: Double,
        elapsedSeconds: Double
    ) {
        self.tickIndex = tickIndex
        self.delta = delta
        self.elapsedSeconds = elapsedSeconds
    }
}

/// Timing supplied to one presentation-rate update.
public struct UpdateTime: Hashable, Sendable {
    /// Zero-based presentation frame number since startup.
    public let frameIndex: UInt64
    /// Clamped presentation interval multiplied by ``GameContext/timeScale``.
    public let delta: Double
    /// Same clamped interval before time scaling.
    public let unscaledDelta: Double
    /// Accumulated scaled presentation time in seconds.
    public let elapsedSeconds: Double

    init(
        frameIndex: UInt64,
        delta: Double,
        unscaledDelta: Double,
        elapsedSeconds: Double
    ) {
        self.frameIndex = frameIndex
        self.delta = delta
        self.unscaledDelta = unscaledDelta
        self.elapsedSeconds = elapsedSeconds
    }
}

/// Timing and completed CPU metrics supplied while recording a presentation frame.
public struct RenderTime: Hashable, Sendable {
    /// Zero-based presentation frame number being recorded.
    public let frameIndex: UInt64
    /// Fractional progress toward the next fixed simulation state.
    public let interpolation: Double
    /// CPU measurements from the preceding completed frame, or zero initially.
    public let metrics: PerformanceMetrics

    init(
        frameIndex: UInt64,
        interpolation: Double,
        metrics: PerformanceMetrics = .zero
    ) {
        self.frameIndex = frameIndex
        self.interpolation = interpolation
        self.metrics = metrics
    }
}
