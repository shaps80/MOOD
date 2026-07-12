import Foundation
import PixlPlatform

package final class ExecutionGroup<Program: LaneProgram>: @unchecked Sendable {
    package let laneCount: Int

    private let condition = NSCondition()
    private var workers: [Thread] = []
    private var context: Program.Context?
    private var barrier: LaneBarrier?
    private var remaining = 0
    private var readyCount = 0
    private var generation = 0
    private var isStopping = false

    package init(
        topology: ExecutionTopology?,
        settings: ExecutionSettings = .init()
    ) {
        laneCount = settings.resolvedLaneCount(for: topology)
        workers.reserveCapacity(max(0, laneCount - 1))

        for index in 1..<laneCount {
            let worker = Thread { [self] in workerLoop(index: index) }
            workers.append(worker)
            worker.start()
        }

        condition.lock()
        while readyCount < laneCount - 1 { condition.wait() }
        condition.unlock()
    }

    deinit {
        condition.lock()
        isStopping = true
        generation &+= 1
        condition.broadcast()
        condition.unlock()

        while workers.contains(where: { !$0.isFinished }) {
            Thread.sleep(forTimeInterval: 0.000_1)
        }
    }

    package func run(_ context: Program.Context) {
        let barrier = LaneBarrier(participantCount: laneCount)

        condition.lock()
        self.context = context
        self.barrier = barrier
        remaining = laneCount - 1
        generation &+= 1
        condition.broadcast()
        condition.unlock()

        Program.execute(
            context,
            on: Lane(index: 0, count: laneCount, barrier: barrier)
        )

        condition.lock()
        while remaining > 0 { condition.wait() }
        self.context = nil
        self.barrier = nil
        condition.unlock()
    }

    private func workerLoop(index: Int) {
        var observedGeneration = 0

        condition.lock()
        readyCount += 1
        condition.broadcast()
        condition.unlock()

        while true {
            condition.lock()
            while generation == observedGeneration && !isStopping {
                condition.wait()
            }
            guard !isStopping else {
                condition.unlock()
                return
            }

            observedGeneration = generation
            let context = context
            let barrier = barrier
            condition.unlock()

            guard let context, let barrier else { continue }
            Program.execute(
                context,
                on: Lane(index: index, count: laneCount, barrier: barrier)
            )

            condition.lock()
            remaining -= 1
            if remaining == 0 { condition.broadcast() }
            condition.unlock()
        }
    }
}
