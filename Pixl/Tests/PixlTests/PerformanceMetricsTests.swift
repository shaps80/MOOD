import Testing
@testable import Pixl

@Suite("Performance metrics")
struct PerformanceMetricsTests {
    @Test
    func summaryReportsAFrameOverTwoPresentationIntervalsAsAHitch() throws {
        var collector = PerformanceMetricsCollector(
            preferredFramesPerSecond: 60
        )

        let metrics = collector.record(
            frameIndex: 1,
            frameTimeSeconds: 1,
            cpuGameSeconds: 0.01,
            cpuRenderSeconds: 0.02
        )
        let summary = metrics.summary

        #expect(summary.frameCount == 1)
        #expect(summary.framesPerSecond == 1)
        #expect(summary.averageFrameTimeSeconds == 1)
        #expect(summary.maximumFrameTimeSeconds == 1)
        #expect(summary.hitchCount == 1)
        #expect(metrics.totalHitchCount == 1)
        #expect(summary.hitchThresholdSeconds == 1.0 / 30.0)
        #expect(summary.description.contains("Hitches: 1"))
    }
}
