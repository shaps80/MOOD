import Foundation
import PixlParticles
import PixlRenderer

nonisolated final class Mailbox: @unchecked Sendable {
    private static let presentationWindow = 3.0
    private static let presentationCapacity = 512

    struct Frame {
        let isPaused: Bool
        let capturesDiagnostics: Bool
        let frameBudget: Double
        let pointLOD: PointLOD
        let groundPlane: GroundPlane
        let cullingBounds: CullingBounds
        let cameraFrustum: CameraFrustum
        let cullingViewProjection: Matrix4x4
        let viewProjection: Matrix4x4
        let viewport: ViewportSize
    }

    struct Work {
        let frame: Frame?
        let system: System?
        let seekTime: Duration?
        let duration: Duration?
        let shouldStop: Bool
    }

    private let condition = NSCondition()
    private var frame: Frame?
    private var system: System?
    private var seekTime: Duration?
    private var duration: Duration?
    private var hasSeek = false
    private var shouldStop = false
    private var completedTime: Duration?
    private var diagnostics: RenderDiagnostics?
    private var gpuTime: Double?
    private var presentationTimes = [Double](
        repeating: 0,
        count: presentationCapacity
    )
    private var presentationHead = 0
    private var presentationCount = 0
    private var failure: String?

    init(system: System) {
        self.system = system
    }

    func submit(_ frame: Frame) {
        condition.lock()
        self.frame = frame
        condition.signal()
        condition.unlock()
    }

    func replaceSystem(_ system: System) {
        condition.lock()
        self.system = system
        condition.signal()
        condition.unlock()
    }

    func seek(to time: Duration) {
        condition.lock()
        seekTime = time
        hasSeek = true
        condition.signal()
        condition.unlock()
    }

    func setDuration(_ duration: Duration) {
        condition.lock()
        self.duration = duration
        condition.signal()
        condition.unlock()
    }

    func next() -> Work {
        condition.lock()
        while frame == nil && system == nil && !hasSeek && duration == nil
            && !shouldStop {
            condition.wait()
        }
        let work = Work(
            frame: frame,
            system: system,
            seekTime: hasSeek ? seekTime : nil,
            duration: duration,
            shouldStop: shouldStop
        )
        frame = nil
        system = nil
        seekTime = nil
        duration = nil
        hasSeek = false
        condition.unlock()
        return work
    }

    func complete(
        at time: Duration,
        visibleCount: Int?,
        cpuSimulationTime: Double,
        cpuRenderTime: Double?,
        frameBudget: Double?
    ) {
        condition.lock()
        completedTime = time
        diagnostics = frameBudget.map {
            let presentation = presentationMetrics()
            return RenderDiagnostics(
                visibleCount: visibleCount,
                cpuSimulationTime: cpuSimulationTime,
                cpuRenderTime: cpuRenderTime,
                gpuTime: gpuTime,
                frameBudget: $0,
                presentationFrameCount: presentation.frameCount,
                presentationDuration: presentation.duration
            )
        }
        condition.unlock()
    }

    func recordGPUTime(_ duration: Double?) {
        condition.lock()
        gpuTime = duration
        condition.unlock()
    }

    func recordPresentation(at time: Double) {
        condition.lock()
        let index: Int
        if presentationCount == Self.presentationCapacity {
            index = presentationHead
            presentationHead = (presentationHead + 1)
                % Self.presentationCapacity
        } else {
            index = (presentationHead + presentationCount)
                % Self.presentationCapacity
            presentationCount += 1
        }
        presentationTimes[index] = time
        condition.unlock()
    }

    private func presentationMetrics() -> (frameCount: Int, duration: Double) {
        guard presentationCount > 1 else { return (0, 0) }
        var latest = -Double.infinity
        for offset in 0..<presentationCount {
            let index = (presentationHead + offset) % Self.presentationCapacity
            latest = max(latest, presentationTimes[index])
        }
        let cutoff = latest - Self.presentationWindow
        var earliest = Double.infinity
        var count = 0
        for offset in 0..<presentationCount {
            let index = (presentationHead + offset) % Self.presentationCapacity
            let time = presentationTimes[index]
            guard time >= cutoff, time <= latest else { continue }
            earliest = min(earliest, time)
            count += 1
        }
        guard count > 1, latest > earliest else { return (0, 0) }
        return (count - 1, latest - earliest)
    }

    func result() -> (time: Duration?, diagnostics: RenderDiagnostics?, failure: String?) {
        condition.lock()
        let result = (completedTime, diagnostics, failure)
        completedTime = nil
        diagnostics = nil
        condition.unlock()
        return result
    }

    func fail(_ message: String) {
        condition.lock()
        failure = message
        condition.unlock()
    }

    func stop() {
        condition.lock()
        shouldStop = true
        condition.signal()
        condition.unlock()
    }
}
