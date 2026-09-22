import Synchronization
import PixlEditorSupport
import PixlParticles
import PixlRenderer

nonisolated final class Mailbox: @unchecked Sendable {
    struct Frame {
        let isPaused: Bool
        let capturesDiagnostics: Bool
        let frameBudget: Double
        let renderer: ParticleRenderer
        let renderValues: ParticleRenderValues
        let pointLOD: PointLOD
        let editor: PixlEditorSupport.Frame
        let cullingBounds: CullingBounds
        let cullingViewProjection: Matrix4x4
        let camera: CameraFrame
    }

    struct Work {
        let frame: Frame?
        let system: System?
        let seekTime: Duration?
        let duration: Duration?
        let shouldStop: Bool
    }

    // UI publishes complete snapshots. Per-field revisions ensure that frame
    // coalescing cannot discard an unconsumed control or replay an old command.
    private struct Input {
        var frame: Frame?
        var frameRevision: UInt64 = 0
        var system: System?
        var systemRevision: UInt64 = 0
        var seekTime: Duration?
        var seekRevision: UInt64 = 0
        var duration: Duration?
        var durationRevision: UInt64 = 0
    }

    private struct Output {
        var time: Duration?
        var timeRevision: UInt64 = 0
        var failure: String?
    }

    private let input = LatestValueChannel<Input>()
    private let output = LatestValueChannel<Output>()
    private let stopped = Atomic<Bool>(false)

    // UI-owned state; no render-thread access.
    private var pending = Input()
    private var reportedTimeRevision: UInt64 = 0
    private var reportedFailure: String?

    // Render-worker-owned state; no UI access after initialization.
    private var consumed = Input()
    private var completed = Output()

    init(system: System) {
        pending.system = system
        pending.systemRevision = 1
        input.publish(pending)
    }

    func submit(_ frame: Frame) {
        pending.frame = frame
        pending.frameRevision &+= 1
        input.publish(pending)
    }

    func replaceSystem(_ system: System) {
        pending.system = system
        pending.systemRevision &+= 1
        input.publish(pending)
    }

    func seek(to time: Duration) {
        pending.seekTime = time
        pending.seekRevision &+= 1
        input.publish(pending)
    }

    func setDuration(_ duration: Duration) {
        pending.duration = duration
        pending.durationRevision &+= 1
        input.publish(pending)
    }

    /// Render worker only. Spin on atomic publication until work or shutdown;
    /// the UI never waits for the worker. No sleeping or OS synchronization.
    func next() -> Work {
        while !stopped.load(ordering: .acquiring) {
            guard let latest = input.take() else { continue }
            let work = Work(
                frame: latest.frameRevision != consumed.frameRevision
                    ? latest.frame : nil,
                system: latest.systemRevision != consumed.systemRevision
                    ? latest.system : nil,
                seekTime: latest.seekRevision != consumed.seekRevision
                    ? latest.seekTime : nil,
                duration: latest.durationRevision != consumed.durationRevision
                    ? latest.duration : nil,
                shouldStop: false
            )
            consumed = latest
            return work
        }
        return Work(
            frame: nil, system: nil, seekTime: nil, duration: nil,
            shouldStop: true
        )
    }

    func complete(at time: Duration) {
        completed.time = time
        completed.timeRevision &+= 1
        output.publish(completed)
    }

    func result() -> (time: Duration?, failure: String?) {
        guard let latest = output.take() else { return (nil, reportedFailure) }
        let time = latest.timeRevision != reportedTimeRevision ? latest.time : nil
        reportedTimeRevision = latest.timeRevision
        reportedFailure = latest.failure
        return (time, reportedFailure)
    }

    func fail(_ message: String) {
        completed.failure = message
        output.publish(completed)
    }

    func stop() {
        stopped.store(true, ordering: .releasing)
    }
}
