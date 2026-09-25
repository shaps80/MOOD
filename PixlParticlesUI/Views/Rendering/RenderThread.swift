import Foundation
import PixlProfiler
import PixlEditorSupport
import PixlEditorSupportMetal
import PixlMetal
@_spi(EditorDiagnostics) import PixlParticles
import PixlRenderer
import QuartzCore

@MainActor
final class RenderThread {
    private let mailbox: Mailbox
    private let worker: Worker
    private let thread: Thread
    private let profiling: ProfileConsumer
    private let recording: EditorRecording

    init(layer: CAMetalLayer, system: System, recording: EditorRecording) {
        self.recording = recording
        let mailbox = Mailbox(system: system)
        let capture = ProfileCapture()
        profiling = ProfileConsumer(capture: capture)
        let worker = Worker(layer: layer, mailbox: mailbox, capture: capture, recording: recording)
        self.mailbox = mailbox
        self.worker = worker
        thread = Thread { worker.run() }
        thread.name = "Pixl Particles Render"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    deinit {
        mailbox.stop()
    }

    func submit(_ frame: Mailbox.Frame) {
        mailbox.submit(frame)
    }

    func replaceSystem(_ system: System) {
        mailbox.replaceSystem(system)
    }

    func seek(to time: Duration) {
        mailbox.seek(to: time)
    }

    func setDuration(_ duration: Duration) {
        mailbox.setDuration(duration)
    }

    func result() -> (time: Duration?, diagnostics: RenderDiagnostics?, failure: String?) {
        let result = mailbox.result()
        return (result.time, profiling.consume(), result.failure)
    }
}

private nonisolated final class Worker: @unchecked Sendable {
    private let layer: CAMetalLayer
    private let mailbox: Mailbox

    private let capture: ProfileCapture
    private let recording: EditorRecording

    init(layer: CAMetalLayer, mailbox: Mailbox, capture: ProfileCapture, recording: EditorRecording) {
        self.recording = recording
        self.layer = layer
        self.mailbox = mailbox
        self.capture = capture
    }

    func run() {
        guard let device = layer.device else {
            mailbox.fail("Metal layer has no device")
            return
        }

        do {
            let metal = try PixlMetal.Platform(device: device, layer: layer)
            let platform = try PixlEditorSupportMetal.Platform(
                base: metal,
                device: device
            )
            let editor = try PixlEditorSupport.Renderer(platform: platform)
            let backend = try ComposedDeviceBackend(
                platform: platform,
                composition: editor
            )
            backend.onGPUTimings = { [capture] duration in
                capture.gpuTimes.record(duration)
            }
            backend.onGPUTrace = { [recording] interval in recording.recordGPU(interval) }
            backend.onPresented = { [capture] time in
                capture.presentations.record(time)
            }
            let renderer = PixlParticles.Renderer(backend: backend)
            let configuration = recording.configuration
            let jobs = configuration.mode == .serial ? nil : SpinningJobPool(
                workerCount: configuration.count,
                batchesPerWorker: configuration.batchesPerWorker,
                recorder: recording.render, workerRecorders: recording.workers
            )
            // Systems may retain the executor after this worker exits.
            defer { jobs?.setSuspended(true) }
            var system: System?
            var isPaused = true
            var frameID: UInt64 = 0

            while true {
                let waitToken = recording.render.begin(EditorProfileDefinitions.mailbox)
                let work = mailbox.next(waitWhenEmpty: isPaused)
                recording.render.end(waitToken)
                if work.shouldStop { return }
                if let frame = work.frame { isPaused = frame.isPaused }
                // Drain temporary Objective-C/Metal objects after each iteration
                // of this long-lived thread, including skipped frames and errors.
                try autoreleasepool {
                    if let replacement = work.system {
                        replacement.executor = jobs
                        system = replacement
                    }
                    if let duration = work.duration { system?.setDuration(duration) }
                    if let seekTime = work.seekTime {
                        let token = recording.render.begin(EditorProfileDefinitions.seek)
                        system?.seek(to: seekTime)
                        recording.render.end(token)
                    }
                    guard let frame = work.frame, let system else { return }

                    frameID &+= 1
                    jobs?.frameID = frameID
                    backend.traceFrameID = frameID
                    let captureID = recording.gpu.generation
                    backend.traceCaptureID = captureID & 1 == 1 ? captureID : nil
                    let frameToken = recording.render.begin(
                        EditorProfileDefinitions.frame, correlation: frameID
                    )
                    defer { recording.render.end(frameToken) }
                    backend.pointLOD = frame.pointLOD
                    backend.cullingBounds = frame.cullingBounds
                    backend.capturesDiagnostics = frame.capturesDiagnostics
                    editor.frame = frame.editor
                    let simulationToken = recording.render.begin(EditorProfileDefinitions.simulation, correlation: frameID)
                    let simulationStart = frame.capturesDiagnostics
                        ? ContinuousClock.now
                        : nil
                    let diagnosticSample = frame.capturesDiagnostics
                        ? system.diagnosticSample(
                            at: .now,
                            isPaused: frame.isPaused
                        )
                        : nil
                    let sample = diagnosticSample?.sample
                        ?? system.sample(at: .now, isPaused: frame.isPaused)
                    let simulationDuration = simulationStart?.duration(to: .now)
                    recording.render.end(simulationToken)
                    let renderToken = recording.render.begin(EditorProfileDefinitions.renderFrame, correlation: frameID)
                    defer { recording.render.end(renderToken) }
                    try renderer.render(
                        system,
                        renderer: frame.renderer,
                        values: frame.renderValues,
                        interpolation: sample.interpolation,
                        cullingViewProjection: frame.cullingViewProjection,
                        camera: frame.camera
                    )
                    if let simulationDuration {
                        capture.frames.record(FrameProfile(
                            simulatedCount: system.particleCount,
                            visibleCount: backend.visibleCount,
                            simulationDuration: simulationDuration,
                            fixedUpdateTime: diagnosticSample?.fixedUpdateTime,
                            cpuRenderTime: backend.cpuRenderTime,
                            frameBudget: frame.frameBudget
                        ))
                    }
                    mailbox.complete(at: sample.time)
                }
                jobs?.setSuspended(isPaused)
            }
        } catch {
            mailbox.fail(String(describing: error))
        }
    }

}
