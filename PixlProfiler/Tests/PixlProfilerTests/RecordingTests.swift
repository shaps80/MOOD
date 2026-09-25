import Testing
import Dispatch
@testable import PixlProfiler

private enum Definition {
    static let frame = ProfileScope(1, "Frame", kind: .frame)
    static let work = ProfileScope(2, "Work")
    static let thread = ProfileTrack(1, "Worker")
}
struct RecordingTests {
    @Test func resumeReclaimsOldSlotsBeforeNewEvents() {
        let session = ProfileSession(scopes: [Definition.work])
        let recorder = session.prepare(Definition.thread, capacity: 1)
        session.resume(); recorder.end(recorder.begin(Definition.work))
        session.freeze(); session.resume()
        recorder.end(recorder.begin(Definition.work))
        let snapshot = session.snapshot()
        #expect(snapshot.segments.count == 1)
        #expect(snapshot.dropped == 0)
    }
    @Test func recorderKeepsStorageAliveAfterSessionTeardown() {
        var session: ProfileSession? = ProfileSession(scopes: [Definition.work])
        let recorder = session!.prepare(Definition.thread, capacity: 1)
        session!.resume(); session = nil
        recorder.end(recorder.begin(Definition.work))
        #expect(recorder.state.pointee.head.load(ordering: .acquiring) == 1)
    }
    @Test func nearestRankPercentileAndHistoryLimit() {
        let session = ProfileSession(scopes: [Definition.work], maximumEvents: 2)
        let recorder = session.prepare(Definition.thread)
        session.resume()
        let a = ContinuousClock.now
        for value in [0.001, 0.002, 0.003] {
            recorder.record(Definition.work, start: a, end: a.advanced(by: .seconds(value)), generation: recorder.generation)
        }
        let snapshot = session.snapshot()
        #expect(snapshot.segments.count == 2)
        #expect(snapshot.retainedOut == 1)
        #expect(snapshot.statistics.first?.p95 == snapshot.statistics.first?.maximum)
    }
    @Test func nestingOverflowAndFreeze() {
        let session = ProfileSession(scopes: [Definition.frame, Definition.work])
        let recorder = session.prepare(Definition.thread, capacity: 2)
        let disabled = recorder.begin(Definition.work); recorder.end(disabled)
        #expect(session.snapshot().segments.isEmpty)
        session.resume()
        let frame = recorder.begin(Definition.frame, correlation: 10)
        let work = recorder.begin(Definition.work, correlation: 10)
        recorder.end(work); recorder.end(frame)
        recorder.end(recorder.begin(Definition.work))
        session.freeze()
        recorder.end(recorder.begin(Definition.work))
        let snapshot = session.snapshot()
        #expect(snapshot.segments.count == 2)
        #expect(snapshot.dropped == 1)
        #expect(snapshot.segments.map(\.depth) == [0, 1])
        #expect(!snapshot.isRecording)
        #expect(snapshot.statistics.count == 2)
        #expect(snapshot.frames.count == 1)
        #expect(snapshot.trackSegments[0]?.count == 2)
        #expect(snapshot.correlationEnds[10] == snapshot.frames.first?.end)
    }
    @Test func oldTokensAndCallbacksCannotEnterNewCapture() {
        let session = ProfileSession(scopes: [Definition.work])
        let recorder = session.prepare(Definition.thread)
        session.resume()
        let token = recorder.begin(Definition.work)
        let generation = recorder.generation
        let start = ContinuousClock.now
        session.freeze(); session.resume()
        recorder.end(token)
        recorder.record(Definition.work, start: start, end: .now, generation: generation)
        #expect(session.snapshot().segments.isEmpty)
        recorder.end(recorder.begin(Definition.work))
        #expect(session.snapshot().segments.count == 1)
    }
    @Test func queuedGPUWorkMayStartAfterCPUFreeze() {
        let session = ProfileSession(scopes: [Definition.work])
        let recorder = session.prepare(Definition.thread, concurrent: true)
        session.resume()
        let submissionGeneration = recorder.generation
        session.freeze()
        let start = ContinuousClock.now
        recorder.record(Definition.work, start: start, end: start.advanced(by: .milliseconds(2)),
                        generation: submissionGeneration)
        #expect(session.snapshot().segments.count == 1)
    }
    @Test func lateCompletionBeforeFreezeBoundaryIsRetained() {
        let session = ProfileSession(scopes: [Definition.work])
        let recorder = session.prepare(Definition.thread, concurrent: true)
        session.resume()
        let generation = recorder.generation
        let a = ContinuousClock.now, b = ContinuousClock.now
        session.freeze()
        recorder.record(Definition.work, start: a, end: b, generation: generation)
        #expect(session.snapshot().segments.count == 1)
    }
    @Test func concurrentRecordingAndDrainRemainCoherent() {
        let session = ProfileSession(scopes: [Definition.work], maximumEvents: 500_000)
        let recorders = (0..<4).map { session.prepare(Definition.thread, instance: $0, capacity: 1024) }
        session.resume()
        let group = DispatchGroup()
        for recorder in recorders {
            group.enter()
            DispatchQueue.global().async {
                for index in 0..<10_000 {
                    recorder.end(recorder.begin(Definition.work, correlation: UInt64(index)))
                }
                group.leave()
            }
        }
        while group.wait(timeout: .now()) != .success { _ = session.snapshot() }
        session.freeze()
        let snapshot = session.snapshot()
        #expect(snapshot.segments.count + Int(snapshot.dropped) == 40_000)
        #expect(snapshot.segments.allSatisfy { $0.end >= $0.start && $0.correlation < 10_000 })
    }
    @Test func concurrentCallbackTrackAccountsForEveryAttempt() {
        let session = ProfileSession(scopes: [Definition.work], maximumEvents: 100_000)
        let recorder = session.prepare(Definition.thread, capacity: 40_000, concurrent: true)
        session.resume()
        DispatchQueue.concurrentPerform(iterations: 4) { _ in
            for _ in 0..<10_000 { recorder.end(recorder.begin(Definition.work)) }
        }
        session.freeze()
        let snapshot = session.snapshot()
        #expect(snapshot.segments.count + Int(snapshot.dropped) == 40_000)
    }
}
