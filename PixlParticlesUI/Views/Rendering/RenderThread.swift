import Foundation
import PixlMetal
import PixlParticles
import PixlRenderer
import QuartzCore

@MainActor
final class RenderThread {
    private let mailbox: Mailbox
    private let worker: Worker
    private let thread: Thread

    init(layer: CAMetalLayer, system: System) {
        let mailbox = Mailbox(system: system)
        let worker = Worker(layer: layer, mailbox: mailbox)
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
        mailbox.result()
    }
}

private nonisolated final class Worker: @unchecked Sendable {
    private let layer: CAMetalLayer
    private let mailbox: Mailbox

    init(layer: CAMetalLayer, mailbox: Mailbox) {
        self.layer = layer
        self.mailbox = mailbox
    }

    func run() {
        guard let device = layer.device else {
            mailbox.fail("Metal layer has no device")
            return
        }

        do {
            let platform = try PixlMetal.Platform(device: device, layer: layer)
            let backend = try DeviceBackend(platform: platform)
            backend.onGPUTime = { [mailbox] duration in
                mailbox.recordGPUTime(duration)
            }
            backend.onPresented = { [mailbox] time in
                mailbox.recordPresentation(at: time)
            }
            let renderer = PixlParticles.Renderer(backend: backend)
            var system: System?

            while true {
                let work = mailbox.next()
                if work.shouldStop { return }
                if let replacement = work.system { system = replacement }
                if let duration = work.duration { system?.setDuration(duration) }
                if let seekTime = work.seekTime { system?.seek(to: seekTime) }
                guard let frame = work.frame, let system else { continue }

                backend.pointLOD = frame.pointLOD
                backend.groundPlane = frame.groundPlane
                backend.cullingBounds = frame.cullingBounds
                backend.cameraFrustum = frame.cameraFrustum
                backend.capturesDiagnostics = frame.capturesDiagnostics
                let simulationStart = frame.capturesDiagnostics
                    ? ContinuousClock.now
                    : nil
                let sample = system.sample(at: .now, isPaused: frame.isPaused)
                let simulationTime = simulationStart.map {
                    Self.seconds($0.duration(to: .now))
                } ?? 0
                try renderer.render(
                    system,
                    interpolation: sample.interpolation,
                    tick: sample.tick,
                    cullingViewProjection: frame.cullingViewProjection,
                    viewProjection: frame.viewProjection,
                    viewport: frame.viewport
                )
                mailbox.complete(
                    at: sample.time,
                    visibleCount: backend.visibleCount,
                    cpuSimulationTime: simulationTime,
                    cpuRenderTime: backend.cpuRenderTime,
                    frameBudget: frame.capturesDiagnostics
                        ? frame.frameBudget
                        : nil
                )
            }
        } catch {
            mailbox.fail(String(describing: error))
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1e18
    }
}
