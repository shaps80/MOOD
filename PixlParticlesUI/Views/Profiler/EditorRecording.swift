import PixlProfiler
import PixlProfilerUI
import PixlRenderer
import PixlParticles
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
    func recordSimulation(_ interval: SimulationTraceInterval) {
        let scope: ProfileScope
        switch interval.phase {
        case .clockScheduling: scope = EditorProfileDefinitions.simClockScheduling
        case .fixedUpdate: scope = EditorProfileDefinitions.simFixedUpdate
        case .sampleResult: scope = EditorProfileDefinitions.simSampleResult
        case .scheduling: scope = EditorProfileDefinitions.simScheduling
        case .integration: scope = EditorProfileDefinitions.simIntegration
        case .recycling: scope = EditorProfileDefinitions.simRecycling
        case .generation: scope = EditorProfileDefinitions.simGeneration
        case .retirement: scope = EditorProfileDefinitions.simRetirement
        case .allocation: scope = EditorProfileDefinitions.simAllocation
        case .commit: scope = EditorProfileDefinitions.simCommit
        }
        render.record(scope, start: interval.start, end: interval.end,
                      generation: interval.captureID, correlation: interval.frameID)
    }
    func recordCPU(_ interval: CPUTraceInterval) {
        let scope: ProfileScope
        switch interval.phase {
        case .frameWait: scope = EditorProfileDefinitions.cpuFrameWait
        case .buffers: scope = EditorProfileDefinitions.cpuBuffers
        case .commandBuffer: scope = EditorProfileDefinitions.cpuCommandBuffer
        case .computeEncoding: scope = EditorProfileDefinitions.cpuComputeEncoding
        case .composition: scope = EditorProfileDefinitions.cpuComposition
        case .drawableWait: scope = EditorProfileDefinitions.cpuDrawableWait
        case .drawEncoding: scope = EditorProfileDefinitions.cpuDrawEncoding
        case .submission: scope = EditorProfileDefinitions.cpuSubmission
        }
        render.record(scope, start: interval.start, end: interval.end,
                      generation: interval.captureID, correlation: interval.frameID)
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
        let resolvedScope: ProfileScope
        switch interval.computePhase {
        case .rasterClear: resolvedScope = EditorProfileDefinitions.gpuRasterClear
        case .rasterCoverage: resolvedScope = EditorProfileDefinitions.gpuRasterCoverage
        case .refinementDispatch: resolvedScope = EditorProfileDefinitions.gpuRefinementDispatch
        case .depthSeed: resolvedScope = EditorProfileDefinitions.gpuDepthSeed
        case .depthHierarchy: resolvedScope = EditorProfileDefinitions.gpuDepthHierarchy
        case .compactSurvivors: resolvedScope = EditorProfileDefinitions.gpuCompactSurvivors
        case .refineCoverage: resolvedScope = EditorProfileDefinitions.gpuRefineCoverage
        case .cullClassify: resolvedScope = EditorProfileDefinitions.gpuCullClassify
        case .cullScatter: resolvedScope = EditorProfileDefinitions.gpuCullScatter
        case .cullScan: resolvedScope = EditorProfileDefinitions.gpuCullScan
        case .cullOffsets: resolvedScope = EditorProfileDefinitions.gpuCullOffsets
        case .cullFinish: resolvedScope = EditorProfileDefinitions.gpuCullFinish
        case .lodPrepare: resolvedScope = EditorProfileDefinitions.gpuLodPrepare
        case .lodClear: resolvedScope = EditorProfileDefinitions.gpuLodClear
        case .lodCount: resolvedScope = EditorProfileDefinitions.gpuLodCount
        case .lodThresholds: resolvedScope = EditorProfileDefinitions.gpuLodThresholds
        case .lodClassify: resolvedScope = EditorProfileDefinitions.gpuLodClassify
        case .lodScatter: resolvedScope = EditorProfileDefinitions.gpuLodScatter
        case .lodScan: resolvedScope = EditorProfileDefinitions.gpuLodScan
        case .lodOffsets: resolvedScope = EditorProfileDefinitions.gpuLodOffsets
        case .lodFinish: resolvedScope = EditorProfileDefinitions.gpuLodFinish
        default: resolvedScope = scope
        }
        // Transfer Metal's calibrated uptime into the profiler clock near receipt.
        // Keep the actual start/end interval; callback arrival is not execution time.
        let uptime = CACurrentMediaTime()
        let instant = ContinuousClock.now
        gpu.record(resolvedScope, start: instant.advanced(by: .seconds(interval.start - uptime)),
                   end: instant.advanced(by: .seconds(interval.end - uptime)),
                   generation: interval.captureID, correlation: interval.frameID)
        didCompleteGPU()
    }
}

