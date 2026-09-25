import Foundation
#if canImport(PixlProfiler)
import PixlProfiler
#endif
@_silgen_name("profile_allocations_begin") func allocationsBegin()
@_silgen_name("profile_allocations_end") func allocationsEnd() -> UInt64

private final class ThreadResult: @unchecked Sendable { var allocations: UInt64 = 0 }

@main struct RecordingBenchmarks {
    static let work = ProfileScope(1, "Work")
    static let track = ProfileTrack(1, "Thread")
    @inline(never) static func record(_ recorder: ProfileRecorder, count: Int) {
        for i in 0..<count { recorder.end(recorder.begin(work, correlation: UInt64(i))) }
    }
    static func main() {
        let count = 250_000
        let session = ProfileSession(scopes: [work], maximumEvents: count)
        let recorder = session.prepare(track, capacity: count)
        // Force the runtime, static definitions and both paths before measuring.
        record(recorder, count: 1)
        session.resume(); record(recorder, count: 100); _ = session.snapshot(); session.freeze()
        for enabled in [false, true] {
            if enabled { session.resume() }
            let start = ContinuousClock.now
            allocationsBegin()
            record(recorder, count: count)
            let allocations = allocationsEnd()
            let duration = start.duration(to: .now).components
            let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
            print("\(enabled ? "recording" : "disabled"): \(seconds * 1e9 / Double(count)) ns/scope; \(allocations) allocations")
            precondition(allocations == 0, "Recording allocated")
        }
        session.freeze()
        let trace = session.snapshot()
        precondition(trace.segments.count == count && trace.dropped == 0)
        // Check first clock/recording use on a fresh worker, not just a warmed caller.
        let freshSession = ProfileSession(scopes: [work])
        let freshRecorder = freshSession.prepare(track)
        freshSession.resume()
        let result = ThreadResult()
        let finished = DispatchSemaphore(value: 0)
        let thread = Thread {
            allocationsBegin()
            freshRecorder.end(freshRecorder.begin(work))
            result.allocations = allocationsEnd()
            finished.signal()
        }
        thread.start(); finished.wait()
        print("fresh worker first scope: \(result.allocations) allocations")
        precondition(result.allocations == 0)
        // Positive control: prove the interposer sees a retained Swift allocation.
        allocationsBegin()
        let array = Array(repeating: UInt64(7), count: 100_000)
        let detected = allocationsEnd()
        print("allocation-probe positive control: \(detected), checksum \(array.reduce(0, +))")
        precondition(detected > 0)
    }
}
