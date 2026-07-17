import Testing
@testable import Pixl

@Suite("Loop")
struct LoopTests {
    @Test
    func firstFrameStartsWithoutElapsedTime() {
        var loop = Loop(settings: .default)

        let schedule = loop.advance(to: .now)

        #expect(schedule.fixedUpdateCount == 0)
        #expect(schedule.updateTime.frameIndex == 0)
        #expect(schedule.updateTime.deltaSeconds == 0)
        #expect(schedule.updateTime.elapsedSeconds == 0)
        #expect(schedule.renderTime.interpolation == 0)
    }

    @Test
    func fixedUpdatesAccumulateAndExposeInterpolation() {
        var loop = Loop(
            settings: LoopSettings(
                fixedStep: FixedStep(
                    updatesPerSecond: 60,
                    maximumUpdatesPerFrame: 8
                )
            )
        )
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let first = loop.advance(to: start.advanced(by: .milliseconds(10)))
        #expect(first.fixedUpdateCount == 0)
        #expect(abs(first.renderTime.interpolation - 0.6) < 0.000_001)

        let second = loop.advance(to: start.advanced(by: .milliseconds(20)))
        #expect(second.fixedUpdateCount == 1)
        #expect(second.firstTickIndex == 1)
        #expect(second.fixedDeltaSeconds == 1.0 / 60.0)
        #expect(abs(second.renderTime.interpolation - 0.2) < 0.000_001)
    }

    @Test
    func fixedCatchUpIsCapped() {
        var loop = Loop(
            settings: LoopSettings(
                maximumDeltaSeconds: 0.25,
                fixedStep: FixedStep(
                    updatesPerSecond: 60,
                    maximumUpdatesPerFrame: 2
                )
            )
        )
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let schedule = loop.advance(to: start.advanced(by: .seconds(1)))

        #expect(schedule.fixedUpdateCount == 2)
        #expect(schedule.firstTickIndex == 1)
        #expect(schedule.updateTime.deltaSeconds == 0.25)
        #expect(abs(schedule.renderTime.interpolation) < 0.000_001)
    }

    @Test
    func variableOnlyModeRunsWithoutFixedUpdates() {
        var loop = Loop(
            settings: LoopSettings(
                maximumDeltaSeconds: 0.25,
                fixedStep: nil
            )
        )
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let schedule = loop.advance(to: start.advanced(by: .milliseconds(20)))

        #expect(schedule.fixedUpdateCount == 0)
        #expect(schedule.updateTime.frameIndex == 1)
        #expect(abs(schedule.updateTime.deltaSeconds - 0.02) < 0.000_001)
        #expect(abs(schedule.updateTime.elapsedSeconds - 0.02) < 0.000_001)
        #expect(schedule.renderTime.interpolation == 1)
        #expect(abs(schedule.frameTimeSeconds - 0.02) < 0.000_001)
    }

    @Test
    func frameTimeRetainsTheUnclampedPresentationInterval() {
        var loop = Loop(
            settings: LoopSettings(
                maximumDeltaSeconds: 0.25,
                fixedStep: nil
            )
        )
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let schedule = loop.advance(to: start.advanced(by: .seconds(1)))

        #expect(schedule.updateTime.deltaSeconds == 0.25)
        #expect(schedule.frameTimeSeconds == 1)
    }

    @Test
    func zeroTimeScalePausesSimulationWithoutPausingPresentation() {
        var loop = Loop(settings: .default)
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let paused = loop.advance(
            to: start.advanced(by: .seconds(1)),
            timeScale: 0
        )
        #expect(paused.fixedUpdateCount == 0)
        #expect(paused.updateTime.deltaSeconds == 0)
        #expect(paused.updateTime.elapsedSeconds == 0)
        #expect(paused.frameTimeSeconds == 1)

        let resumed = loop.advance(
            to: start.advanced(by: .seconds(1.02)),
            timeScale: 1
        )
        #expect(resumed.fixedUpdateCount == 1)
        #expect(abs(resumed.updateTime.deltaSeconds - 0.02) < 0.000_001)
        #expect(abs(resumed.updateTime.elapsedSeconds - 0.02) < 0.000_001)
    }

    @Test
    func timeScaleChangesSimulationSpeed() {
        var loop = Loop(
            settings: LoopSettings(
                maximumDeltaSeconds: 1,
                fixedStep: FixedStep(
                    updatesPerSecond: 60,
                    maximumUpdatesPerFrame: 8
                )
            )
        )
        let start = ContinuousClock.now
        _ = loop.advance(to: start)

        let slow = loop.advance(
            to: start.advanced(by: .milliseconds(20)),
            timeScale: 0.5
        )
        #expect(slow.fixedUpdateCount == 0)
        #expect(abs(slow.updateTime.deltaSeconds - 0.01) < 0.000_001)

        let fast = loop.advance(
            to: start.advanced(by: .milliseconds(30)),
            timeScale: 2
        )
        #expect(fast.fixedUpdateCount == 1)
        #expect(abs(fast.updateTime.deltaSeconds - 0.02) < 0.000_001)
        #expect(abs(fast.updateTime.elapsedSeconds - 0.03) < 0.000_001)
    }
}
