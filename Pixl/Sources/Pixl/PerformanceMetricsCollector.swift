import Swift

/// Fixed-window CPU metrics aggregation owned by the game runtime.
struct PerformanceMetricsCollector {
    private static let summaryWindowSeconds = 1.0

    private let hitchThresholdSeconds: Double
    private var elapsedSeconds = 0.0
    private var frameCount: UInt64 = 0
    private var gameSeconds = 0.0
    private var renderSeconds = 0.0
    private var maximumFrameSeconds = 0.0
    private var hitchCount: UInt64 = 0
    private var totalHitchCount: UInt64 = 0
    private var latestSummary: PerformanceMetrics.Summary = .zero

    init(preferredFramesPerSecond: Int) {
        hitchThresholdSeconds = 2 / Double(preferredFramesPerSecond)
    }

    mutating func record(
        frameIndex: UInt64,
        frameTimeSeconds: Double,
        cpuGameSeconds: Double,
        cpuRenderSeconds: Double,
        drawCount: UInt32 = 0,
        activeEntityCount: UInt32 = 0,
        inactiveEntityCount: UInt32 = 0
    ) -> PerformanceMetrics {
        elapsedSeconds += frameTimeSeconds
        frameCount &+= 1
        gameSeconds += cpuGameSeconds
        renderSeconds += cpuRenderSeconds
        maximumFrameSeconds = max(maximumFrameSeconds, frameTimeSeconds)

        if frameTimeSeconds > hitchThresholdSeconds {
            hitchCount &+= 1
            totalHitchCount &+= 1
        }

        if elapsedSeconds >= Self.summaryWindowSeconds {
            latestSummary = .init(
                frameCount: frameCount,
                durationSeconds: elapsedSeconds,
                framesPerSecond: Double(frameCount) / elapsedSeconds,
                averageFrameTimeSeconds: elapsedSeconds / Double(frameCount),
                maximumFrameTimeSeconds: maximumFrameSeconds,
                averageCPUTimeSeconds: gameSeconds / Double(frameCount),
                averageRenderTimeSeconds: renderSeconds / Double(frameCount),
                hitchCount: hitchCount,
                hitchThresholdSeconds: hitchThresholdSeconds
            )
            resetWindow()
        }

        return PerformanceMetrics(
            frameIndex: frameIndex,
            frameTimeSeconds: frameTimeSeconds,
            cpuGameSeconds: cpuGameSeconds,
            cpuRenderSeconds: cpuRenderSeconds,
            drawCount: drawCount,
            activeEntityCount: activeEntityCount,
            inactiveEntityCount: inactiveEntityCount,
            totalHitchCount: totalHitchCount,
            summary: latestSummary
        )
    }

    private mutating func resetWindow() {
        elapsedSeconds = 0
        frameCount = 0
        gameSeconds = 0
        renderSeconds = 0
        maximumFrameSeconds = 0
        hitchCount = 0
    }
}
