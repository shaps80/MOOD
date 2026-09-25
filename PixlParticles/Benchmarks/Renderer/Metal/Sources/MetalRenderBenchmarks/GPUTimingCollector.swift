import Foundation
import PixlRenderer

/// One completed frame at a time deliberately isolates GPU work from queue overlap.
final class GPUTimingCollector: @unchecked Sendable {
    private let condition = NSCondition()
    private var result: GPUFrameTimings?

    func record(_ result: GPUFrameTimings) {
        condition.lock()
        self.result = result
        condition.signal()
        condition.unlock()
    }

    func take() throws -> GPUFrameTimings {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date(timeIntervalSinceNow: 10)
        while result == nil {
            guard condition.wait(until: deadline) else { throw Failure.noCompletedFrame }
        }
        let value = result!
        result = nil
        return value
    }

    enum Failure: Error { case noCompletedFrame }
}
