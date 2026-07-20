import Swift
import PixlFoundation

/// Fixed-window CPU metrics aggregation owned by the game runtime.
struct PerformanceMetricsCollector {
    private static let summaryWindowSeconds = 1.0

    private let hitchThresholdSeconds: Double
    private var elapsedSeconds = 0.0
    private var frameCount: UInt64 = 0
    private var gameSeconds = 0.0
    private var renderSeconds = 0.0
    private var renderLoweringSeconds = 0.0
    private var renderCullingSeconds = 0.0
    private var renderLayerBinningSeconds = 0.0
    private var renderOrderingSeconds = 0.0
    private var renderBatchingSeconds = 0.0
    private var renderInstancesSeconds = 0.0
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
        renderQueue: RenderQueue.Metrics = .init()
    ) -> PerformanceMetrics {
        elapsedSeconds += frameTimeSeconds
        frameCount &+= 1
        gameSeconds += cpuGameSeconds
        renderSeconds += cpuRenderSeconds
        renderLoweringSeconds += renderQueue.loweringSeconds
        renderCullingSeconds += renderQueue.cullingSeconds
        renderLayerBinningSeconds += renderQueue.layerBinningSeconds
        renderOrderingSeconds += renderQueue.orderingSeconds
        renderBatchingSeconds += renderQueue.batchingSeconds
        renderInstancesSeconds += renderQueue.instancesSeconds
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
                averageRenderLoweringSeconds: renderLoweringSeconds / Double(frameCount),
                averageRenderCullingSeconds: renderCullingSeconds / Double(frameCount),
                averageRenderLayerBinningSeconds: renderLayerBinningSeconds / Double(frameCount),
                averageRenderOrderingSeconds: renderOrderingSeconds / Double(frameCount),
                averageRenderBatchingSeconds: renderBatchingSeconds / Double(frameCount),
                averageRenderInstancesSeconds: renderInstancesSeconds / Double(frameCount),
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
            totalHitchCount: totalHitchCount,
            summary: latestSummary
        )
    }

    private mutating func resetWindow() {
        elapsedSeconds = 0
        frameCount = 0
        gameSeconds = 0
        renderSeconds = 0
        renderLoweringSeconds = 0
        renderCullingSeconds = 0
        renderLayerBinningSeconds = 0
        renderOrderingSeconds = 0
        renderBatchingSeconds = 0
        renderInstancesSeconds = 0
        maximumFrameSeconds = 0
        hitchCount = 0
    }
}
