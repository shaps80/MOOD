#if canImport(SwiftUI)
import Testing
import PixlProfiler
import PixlProfilerUI

@MainActor struct ControllerTests {
    static let frame = ProfileScope(1, "Frame", kind: .frame)
    static let gpu = ProfileScope(2, "GPU", kind: .gpuFrame)
    static let track = ProfileTrack(1, "Render")

    @Test func frozenCaptureReceivesLateResultsWithoutPolling() async throws {
        let session = ProfileSession(scopes: [Self.frame, Self.gpu])
        let recorder = session.prepare(Self.track)
        let controller = ProfileController(session: session)
        let completed = controller.externalCompletionHandler()
        controller.resume()
        try await until { controller.snapshot.isRecording }
        let generation = recorder.generation
        recorder.end(recorder.begin(Self.frame, correlation: 1))
        controller.freeze()
        try await until { !controller.snapshot.isRecording && controller.snapshot.segments.count == 1 }
        let start = ContinuousClock.now
        recorder.record(Self.gpu, start: start, end: .now, generation: generation, correlation: 1)
        completed()
        try await until { controller.snapshot.segments.count == 2 }
        #expect(!controller.snapshot.isRecording)
        controller.resume()
        try await until { controller.snapshot.isRecording && controller.snapshot.generation != generation }
        recorder.record(Self.gpu, start: start, end: .now, generation: generation)
        controller.freeze()
        try await until { !controller.snapshot.isRecording }
        #expect(controller.snapshot.segments.isEmpty)
    }
    @Test func controllerTeardownDisablesRecording() async throws {
        let session = ProfileSession(scopes: [Self.frame])
        let recorder = session.prepare(Self.track)
        var controller: ProfileController? = ProfileController(session: session)
        controller?.resume()
        try await until { recorder.generation & 1 == 1 }
        controller = nil
        try await until { recorder.generation & 1 == 0 }
    }
    @Test func hiddenControllerDoesNotProcessLateCompletions() async throws {
        let session = ProfileSession(scopes: [Self.frame, Self.gpu])
        let recorder = session.prepare(Self.track)
        let controller = ProfileController(session: session)
        let completed = controller.externalCompletionHandler()
        controller.resume()
        try await until { controller.snapshot.isRecording }
        let generation = recorder.generation
        controller.suspend()
        try await until { recorder.generation & 1 == 0 }
        let count = controller.snapshot.segments.count
        let start = ContinuousClock.now
        recorder.record(Self.gpu, start: start, end: .now, generation: generation, correlation: 1)
        completed()
        try await Task.sleep(for: .milliseconds(60))
        #expect(controller.snapshot.segments.count == count)
        // Reopening paused explicitly drains retained results.
        controller.freeze()
        try await until { controller.snapshot.segments.count == count + 1 }
    }
    private func until(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(predicate())
    }
}
#endif
