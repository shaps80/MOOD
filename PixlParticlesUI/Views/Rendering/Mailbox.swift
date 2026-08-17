import Foundation
import PixlParticles
import PixlRenderer

nonisolated final class Mailbox: @unchecked Sendable {
    struct Frame {
        let isPaused: Bool
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

    func complete(at time: Duration) {
        condition.lock()
        completedTime = time
        condition.unlock()
    }

    func result() -> (time: Duration?, failure: String?) {
        condition.lock()
        let result = (completedTime, failure)
        completedTime = nil
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
