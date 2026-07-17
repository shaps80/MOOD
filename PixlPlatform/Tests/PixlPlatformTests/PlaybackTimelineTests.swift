import Testing
@testable import PixlPlatform

@Suite("Playback timeline")
struct PlaybackTimelineTests {
    @Test
    func loopingPlaybackTracksRatePauseAndResume() {
        var timeline = PlaybackTimeline(
            duration: 10,
            looping: true,
            rate: 1,
            at: 100
        )

        #expect(timeline.currentOffset(at: 103) == 3)

        timeline.setRate(2, at: 103)
        #expect(timeline.currentOffset(at: 105) == 7)

        timeline.pause(at: 106)
        #expect(timeline.currentOffset(at: 200) == 9)

        timeline.resume(at: 200)
        #expect(timeline.currentOffset(at: 202) == 3)
    }

    @Test
    func oneShotExpiresWhileOutputIsUnavailable() {
        var timeline = PlaybackTimeline(
            duration: 2,
            looping: false,
            rate: 1,
            at: 10
        )

        #expect(timeline.currentOffset(at: 11) == 1)
        #expect(timeline.currentOffset(at: 12) == nil)
        #expect(timeline.isFinished)
    }
}
