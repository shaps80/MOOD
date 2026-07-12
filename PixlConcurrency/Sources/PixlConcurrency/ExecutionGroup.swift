import Swift

package final class ExecutionGroup<Program: LaneProgram>: @unchecked Sendable {
    package let laneCount: Int

    private let condition = NativeCondition()
    private let barrier: LaneBarrier
    private var workers: [NativeThread] = []
    private var context: Program.Context?
    private var remaining = 0
    private var readyCount = 0
    private var generation = 0
    private var isRunning = false
    private var isStopping = false

    package init(
        topology: ExecutionTopology? = nil,
        settings: ExecutionSettings = .init()
    ) {
        laneCount = settings.resolvedLaneCount(for: topology ?? .current)
        barrier = LaneBarrier(participantCount: laneCount)
        workers.reserveCapacity(max(0, laneCount - 1))

        for index in 1..<laneCount {
            let worker = NativeThread { [self] in workerLoop(index: index) }
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

        for worker in workers {
            worker.join()
        }
    }

    package func run(_ context: Program.Context) {
        condition.lock()
        precondition(!isRunning, "ExecutionGroup does not support concurrent runs")
        isRunning = true
        self.context = context
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
        isRunning = false
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
            condition.unlock()

            guard let context else { continue }
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
