import Testing
import PixlProfiler
@testable import PixlProfilerUI

struct FrameWindowTests {
    static let frame = ProfileScope(1, "Frame", kind: .frame)
    static let gpu = ProfileScope(2, "GPU", kind: .gpuFrame)
    static let track = ProfileTrack(1, "Render")

    @Test(arguments: [0.005, 0.018])
    func frameFitsActualCompletion(gpuTime: Double) {
        let (snapshot, frame) = capture(gpuTime: gpuTime)
        let range = ProfileFrameWindow.range(in: snapshot, frame: frame)
        #expect(abs(range.upperBound - range.lowerBound - gpuTime) < 1e-9)
    }
    @Test func cpuCompletionCanBeLast() {
        let (snapshot, frame) = capture(gpuTime: 0.001)
        let range = ProfileFrameWindow.range(in: snapshot, frame: frame)
        #expect(abs(range.upperBound - range.lowerBound - 0.002) < 1e-9)
    }
    private func capture(gpuTime: Double) -> (ProfileSnapshot, ProfileSnapshot.Segment) {
        let session = ProfileSession(scopes: [Self.frame, Self.gpu])
        let recorder = session.prepare(Self.track)
        session.resume()
        let start = ContinuousClock.now
        recorder.record(Self.frame, start: start, end: start.advanced(by: .milliseconds(2)),
                        generation: recorder.generation, correlation: 1)
        recorder.record(Self.gpu, start: start, end: start.advanced(by: .seconds(gpuTime)),
                        generation: recorder.generation, correlation: 1)
        // A later frame following a large gap must not stretch the selected frame.
        recorder.record(Self.frame, start: start.advanced(by: .seconds(0.5)),
                        end: start.advanced(by: .seconds(0.502)), generation: recorder.generation,
                        correlation: 2)
        let snapshot = session.snapshot()
        return (snapshot, snapshot.frames.first!)
    }
}
