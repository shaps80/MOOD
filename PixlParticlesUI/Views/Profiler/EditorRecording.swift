import PixlProfiler
import PixlProfilerUI
import PixlRenderer
import QuartzCore

/// Construct once on the main thread; workers only use prebound recorders.
nonisolated final class EditorRecording: Sendable {
    @MainActor let controller: ProfileController
    let didCompleteGPU: @Sendable () -> Void
    let session: ProfileSession
    let render: ProfileRecorder
    let workers: [ProfileRecorder]
    let gpu: ProfileRecorder
    let configuration: SimulationWorkers

    @MainActor init() {
        let session = ProfileSession(scopes: EditorProfileDefinitions.scopes)
        self.session = session
        configuration = SimulationWorkers.environment
        render = session.prepare(EditorProfileDefinitions.render)
        workers = configuration.mode == .serial ? [] : (1..<configuration.count).map {
            session.prepare(EditorProfileDefinitions.worker, instance: $0)
        }
        gpu = session.prepare(EditorProfileDefinitions.gpu, concurrent: true)
        controller = ProfileController(session: session)
        didCompleteGPU = controller.externalCompletionHandler()
    }
    func recordGPU(_ interval: GPUTraceInterval) {
        let scope: ProfileScope
        switch interval.phase {
        case .frame: scope = EditorProfileDefinitions.gpuFrame
        case .preparation: scope = EditorProfileDefinitions.preparation
        case .diagnostics: scope = EditorProfileDefinitions.diagnostics
        case .vertex: scope = EditorProfileDefinitions.vertex
        case .fragment: scope = EditorProfileDefinitions.fragment
        }
        // Transfer Metal's calibrated uptime into the profiler clock near receipt.
        // Keep the actual start/end interval; callback arrival is not execution time.
        let uptime = CACurrentMediaTime()
        let instant = ContinuousClock.now
        gpu.record(scope, start: instant.advanced(by: .seconds(interval.start - uptime)),
                   end: instant.advanced(by: .seconds(interval.end - uptime)),
                   generation: interval.captureID, correlation: interval.frameID)
        didCompleteGPU()
    }
}

