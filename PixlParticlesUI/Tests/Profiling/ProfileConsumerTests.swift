import Testing
@testable import ParticleProfiling

@MainActor
struct ProfileConsumerTests {
    private func frame(_ count: Int) -> FrameProfile {
        FrameProfile(
            simulatedCount: count, visibleCount: count - 1,
            simulationDuration: .milliseconds(2), fixedUpdateTime: 0.001,
            cpuRenderTime: 0.0002, frameBudget: 1 / 60
        )
    }

    @Test func deferredAssemblyAndLatestFrame() {
        let capture = ProfileCapture()
        let consumer = ProfileConsumer(capture: capture)
        #expect(consumer.consume() == nil)
        capture.frames.record(frame(100))
        capture.frames.record(frame(200))
        capture.gpuTimes.record(0.009)
        for time in [10.0, 8.0, 9.0, 6.0] { capture.presentations.record(time) }
        let result = consumer.consume()
        #expect(result?.simulatedCount == 200)
        #expect(result?.visibleCount == 199)
        #expect(result?.cpuSimulationTime == 0.002)
        #expect(result?.fixedUpdateTime == 0.001)
        #expect(result?.gpuTime == 0.009)
        #expect(result?.presentationFrameCount == 2)
        #expect(result?.presentationDuration == 2)
        #expect(consumer.consume() == nil)
    }

    @Test func callbacksWithoutFrameAndNilGPUTime() {
        let capture = ProfileCapture()
        let consumer = ProfileConsumer(capture: capture)
        capture.gpuTimes.record(0.01)
        capture.presentations.record(10)
        #expect(consumer.consume() == nil)
        capture.gpuTimes.record(nil)
        capture.presentations.record(11)
        capture.frames.record(frame(10))
        let result = consumer.consume()
        #expect(result?.gpuTime == nil)
        #expect(result?.presentationFrameCount == 1)
        #expect(result?.presentationDuration == 1)
    }

    @Test func latestFrameAfterSlotWrap() {
        let capture = ProfileCapture()
        let consumer = ProfileConsumer(capture: capture)
        for count in 0..<500 { capture.frames.record(frame(count)) }
        #expect(consumer.consume()?.simulatedCount == 499)
        for count in 500..<530 { capture.frames.record(frame(count)) }
        #expect(consumer.consume()?.simulatedCount == 529)
    }
}
