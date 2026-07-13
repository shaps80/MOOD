import Swift

/// CPU-side measurements for one completed game frame.
///
/// Values are reported on the following frame through ``RenderTime/metrics``
/// so collecting them never waits for the GPU.
public struct PerformanceMetrics: Hashable, Sendable {
    public static let zero = PerformanceMetrics(
        frameIndex: 0,
        frameTimeSeconds: 0,
        cpuGameSeconds: 0,
        cpuRenderSeconds: 0,
        drawCount: 0,
        activeEntityCount: 0,
        inactiveEntityCount: 0,
        totalHitchCount: 0,
        summary: .zero
    )

    /// The frame that produced these measurements.
    public let frameIndex: UInt64

    /// The un-clamped interval between presentation callbacks, in seconds.
    public let frameTimeSeconds: Double

    /// The reciprocal of ``frameTimeSeconds``, or zero when unavailable.
    public let framesPerSecond: Double

    /// Time spent in fixed and variable game updates, in seconds.
    public let cpuGameSeconds: Double

    /// Time spent recording the game's render commands, in seconds.
    public let cpuRenderSeconds: Double

    /// Draw calls recorded into the completed frame.
    public let drawCount: UInt32

    /// Live entities across registered worlds at the end of the completed frame.
    public let activeEntityCount: UInt32

    /// Reusable inactive dense slots across registered worlds.
    public let inactiveEntityCount: UInt32

    /// Hitches observed since game startup.
    public let totalHitchCount: UInt64

    /// The latest completed one-second reporting window.
    public let summary: Summary

    /// Aggregate CPU-side measurements from a one-second reporting window.
    public struct Summary: Hashable, Sendable, CustomStringConvertible {
        public static let zero = Summary(
            frameCount: 0,
            durationSeconds: 0,
            framesPerSecond: 0,
            averageFrameTimeSeconds: 0,
            maximumFrameTimeSeconds: 0,
            averageCPUTimeSeconds: 0,
            averageRenderTimeSeconds: 0,
            hitchCount: 0,
            hitchThresholdSeconds: 0
        )

        public let frameCount: UInt64
        public let durationSeconds: Double
        public let framesPerSecond: Double
        public let averageFrameTimeSeconds: Double
        public let maximumFrameTimeSeconds: Double
        public let averageCPUTimeSeconds: Double
        public let averageRenderTimeSeconds: Double
        public let hitchCount: UInt64
        public let hitchThresholdSeconds: Double

        public var description: String {
            "FPS: \(Self.column(framesPerSecond)) | "
                + "Frame avg: \(Self.column(averageFrameTimeSeconds * 1_000))ms | "
                + "Frame max: \(Self.column(maximumFrameTimeSeconds * 1_000))ms | "
                + "Game avg: \(Self.column(averageCPUTimeSeconds * 1_000))ms | "
                + "Render avg: \(Self.column(averageRenderTimeSeconds * 1_000))ms | "
                + "Hitches: \(hitchCount)"
        }

        private static func column(_ value: Double) -> String {
            let value = String(value)
            guard value.count < 12 else { return value }
            return value + String(repeating: " ", count: 12 - value.count)
        }
    }

    init(
        frameIndex: UInt64,
        frameTimeSeconds: Double,
        cpuGameSeconds: Double,
        cpuRenderSeconds: Double,
        drawCount: UInt32,
        activeEntityCount: UInt32,
        inactiveEntityCount: UInt32,
        totalHitchCount: UInt64,
        summary: Summary
    ) {
        self.frameIndex = frameIndex
        self.frameTimeSeconds = frameTimeSeconds
        framesPerSecond = frameTimeSeconds > 0 ? 1 / frameTimeSeconds : 0
        self.cpuGameSeconds = cpuGameSeconds
        self.cpuRenderSeconds = cpuRenderSeconds
        self.drawCount = drawCount
        self.activeEntityCount = activeEntityCount
        self.inactiveEntityCount = inactiveEntityCount
        self.totalHitchCount = totalHitchCount
        self.summary = summary
    }

}
