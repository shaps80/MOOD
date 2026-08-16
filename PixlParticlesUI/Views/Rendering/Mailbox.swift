import Foundation
import PixlParticles
import PixlRenderer

nonisolated final class Mailbox: @unchecked Sendable {
    struct Frame {
        let isPaused: Bool
        let pointLOD: PointLOD
        let groundPlane: GroundPlane
        let cullingBounds: CullingBounds
        let viewProjection: Matrix4x4
        let viewport: ViewportSize
    }

    struct Work {
        let frame: Frame?
        let system: System?
        let seekTime: Duration?
        let shouldStop: Bool
    }

    private let condition = NSCondition()
    private var frame: Frame?
    private var system: System?
    private var seekTime: Duration?
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

    func next() -> Work {
        condition.lock()
        while frame == nil && system == nil && !hasSeek && !shouldStop {
            condition.wait()
        }
        let work = Work(
            frame: frame,
            system: system,
            seekTime: hasSeek ? seekTime : nil,
            shouldStop: shouldStop
        )
        frame = nil
        system = nil
        seekTime = nil
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
