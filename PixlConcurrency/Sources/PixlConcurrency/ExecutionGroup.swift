import Atomics

package final class ExecutionGroup<Program: LaneProgram>: @unchecked Sendable {
    package var laneCount: Int { state.laneCount }

    private let state: ExecutionState<Program>
    private var workers: [Thread] = []

    package init(
        topology: ExecutionTopology? = nil,
        settings: ExecutionSettings = .init()
    ) {
        let laneCount = settings.resolvedLaneCount(for: topology ?? .current)
        state = ExecutionState(laneCount: laneCount)
        workers.reserveCapacity(max(0, laneCount - 1))

        for index in 1..<laneCount {
            let state = state
            let worker = Thread {
                state.workerLoop(index: index)
            }
            workers.append(worker)
            worker.start()
        }

        state.waitUntilReady()
    }

    deinit {
        state.stop()
        for worker in workers {
            worker.join()
        }
    }

    package func run(_ context: Program.Context) {
        state.run(context)
    }
}

private final class ExecutionState<Program: LaneProgram>: @unchecked Sendable {
    let laneCount: Int

    private let workCondition = Condition()
    private let completionCondition = Condition()
    private let barrier: LaneBarrier
    private var context: Unmanaged<Program.Context>?
    private let remaining = ManagedAtomic<Int>(0)
    private let isRunning = ManagedAtomic<Bool>(false)
    private var readyCount = 0
    private var workGeneration = 0
    private var completionGeneration = 0
    private var isStopping = false

    init(laneCount: Int) {
        self.laneCount = laneCount
        barrier = LaneBarrier(participantCount: laneCount)
    }

    func waitUntilReady() {
        workCondition.lock()
        while readyCount < laneCount - 1 { workCondition.wait() }
        workCondition.unlock()
    }

    func stop() {
        workCondition.lock()
        isStopping = true
        workGeneration &+= 1
        workCondition.broadcast()
        workCondition.unlock()
    }

    func run(_ context: Program.Context) {
        let acquiredRun = isRunning.compareExchange(
            expected: false,
            desired: true,
            ordering: .acquiringAndReleasing
        ).exchanged
        precondition(acquiredRun, "ExecutionGroup does not support concurrent runs")
        defer { isRunning.store(false, ordering: .releasing) }

        let leaderLane = Lane(index: 0, count: laneCount, barrier: barrier)
        guard laneCount > 1 else {
            Program.execute(context, on: leaderLane)
            return
        }

        completionCondition.lock()
        let expectedCompletion = completionGeneration
        completionCondition.unlock()

        remaining.store(laneCount - 1, ordering: .relaxed)

        workCondition.lock()
        self.context = .passUnretained(context)
        workGeneration &+= 1
        workCondition.broadcast()
        workCondition.unlock()

        Program.execute(context, on: leaderLane)

        completionCondition.lock()
        while completionGeneration == expectedCompletion {
            completionCondition.wait()
        }
        completionCondition.unlock()

        workCondition.lock()
        self.context = nil
        workCondition.unlock()
    }

    func workerLoop(index: Int) {
        var observedGeneration = 0

        workCondition.lock()
        readyCount += 1
        workCondition.broadcast()
        workCondition.unlock()

        while true {
            workCondition.lock()
            while workGeneration == observedGeneration && !isStopping {
                workCondition.wait()
            }
            guard !isStopping else {
                workCondition.unlock()
                return
            }

            observedGeneration = workGeneration
            let context = context
            workCondition.unlock()

            guard let context else { continue }
            Program.execute(
                context.takeUnretainedValue(),
                on: Lane(index: index, count: laneCount, barrier: barrier)
            )

            let previousRemaining = remaining.loadThenWrappingDecrement(
                ordering: .acquiringAndReleasing
            )
            precondition(previousRemaining > 0)
            if previousRemaining == 1 {
                completionCondition.lock()
                completionGeneration &+= 1
                completionCondition.signal()
                completionCondition.unlock()
            }
        }
    }
}
