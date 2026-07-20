import Swift

/// CPU-side measurements for one completed game frame.
///
/// Values are reported on the following frame through ``RenderTime/metrics``
/// so collecting them never waits for the GPU.
public struct PerformanceMetrics: Hashable, Sendable {
    /// Metrics containing no elapsed work or reported hitches.
    public static let zero = PerformanceMetrics(
        frameIndex: 0,
        frameTimeSeconds: 0,
        cpuGameSeconds: 0,
        cpuRenderSeconds: 0,
        drawCount: 0,
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

    /// Hitches observed since game startup.
    public let totalHitchCount: UInt64

    /// The latest completed one-second reporting window.
    public let summary: Summary

    /// Aggregate CPU-side measurements from a one-second reporting window.
    public struct Summary: Hashable, Sendable, CustomStringConvertible {
        /// An empty reporting window.
        public static let zero = Summary(
            frameCount: 0,
            durationSeconds: 0,
            framesPerSecond: 0,
            averageFrameTimeSeconds: 0,
            maximumFrameTimeSeconds: 0,
            averageCPUTimeSeconds: 0,
            averageRenderTimeSeconds: 0,
            averageRenderLoweringSeconds: 0,
            averageRenderCullingSeconds: 0,
            averageRenderLayerBinningSeconds: 0,
            averageRenderOrderingSeconds: 0,
            averageRenderBatchingSeconds: 0,
            averageRenderInstancesSeconds: 0,
            hitchCount: 0,
            hitchThresholdSeconds: 0
        )

        /// Presentation frames included in the window.
        public let frameCount: UInt64
        /// Actual wall-clock duration covered by the window.
        public let durationSeconds: Double
        /// Average presentation frequency during the window.
        public let framesPerSecond: Double
        /// Average un-clamped presentation interval.
        public let averageFrameTimeSeconds: Double
        /// Largest un-clamped presentation interval.
        public let maximumFrameTimeSeconds: Double
        /// Average fixed-plus-variable game update CPU time.
        public let averageCPUTimeSeconds: Double
        /// Average render-command recording CPU time.
        public let averageRenderTimeSeconds: Double
        /// Average queue submission-lowering CPU time.
        public let averageRenderLoweringSeconds: Double
        /// Average queue visibility-culling CPU time.
        public let averageRenderCullingSeconds: Double
        /// Average queue layer-binning CPU time.
        public let averageRenderLayerBinningSeconds: Double
        /// Average queue ordering CPU time.
        public let averageRenderOrderingSeconds: Double
        /// Average queue batching CPU time.
        public let averageRenderBatchingSeconds: Double
        /// Average queue instance-compaction CPU time.
        public let averageRenderInstancesSeconds: Double
        /// Frames exceeding ``hitchThresholdSeconds`` in this window.
        public let hitchCount: UInt64
        /// Frame-time threshold used to classify hitches.
        public let hitchThresholdSeconds: Double

        /// Compact multi-line diagnostic summary suitable for periodic logging.
        public var description: String {
            "FPS: \(Self.column(framesPerSecond)) | "
            + "Frame avg: \(Self.column(averageFrameTimeSeconds * 1_000))ms | "
            + "Frame max: \(Self.column(maximumFrameTimeSeconds * 1_000))ms | "
            + "Game avg: \(Self.column(averageCPUTimeSeconds * 1_000))ms | "
            + "Render avg: \(Self.column(averageRenderTimeSeconds * 1_000))ms | "
            + "Window hitches: \(hitchCount)\n"
            + "Render queue | "
            + "Lowering: \(Self.column(averageRenderLoweringSeconds * 1_000))ms | "
            + "Culling: \(Self.column(averageRenderCullingSeconds * 1_000))ms | "
            + "Layer binning: \(Self.column(averageRenderLayerBinningSeconds * 1_000))ms | "
            + "Ordering: \(Self.column(averageRenderOrderingSeconds * 1_000))ms | "
            + "Batching: \(Self.column(averageRenderBatchingSeconds * 1_000))ms | "
            + "Instances: \(Self.column(averageRenderInstancesSeconds * 1_000))ms"
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
        totalHitchCount: UInt64,
        summary: Summary
    ) {
        self.frameIndex = frameIndex
        self.frameTimeSeconds = frameTimeSeconds
        framesPerSecond = frameTimeSeconds > 0 ? 1 / frameTimeSeconds : 0
        self.cpuGameSeconds = cpuGameSeconds
        self.cpuRenderSeconds = cpuRenderSeconds
        self.drawCount = drawCount
        self.totalHitchCount = totalHitchCount
        self.summary = summary
    }

}
