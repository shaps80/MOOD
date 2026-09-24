import Foundation
import Synchronization
#if canImport(PixlParticles)
import PixlParticles
#endif

/// One submitting thread also executes jobs. Background workers spin between generations.
/// execute is synchronous, non-reentrant, and must only be called by its owner.
nonisolated final class SpinningJobPool: SimulationExecutor {
    let workerCount: Int
    let batchesPerWorker: Int
    private let state: State

    init(workerCount: Int, batchesPerWorker: Int = 4) {
        precondition(workerCount > 0 && batchesPerWorker > 0)
        self.workerCount = workerCount
        self.batchesPerWorker = batchesPerWorker
        let state = State()
        self.state = state
        for index in 1..<workerCount {
            let thread = Thread { state.work() }
            thread.name = "Pixl Simulation \(index)"
            thread.qualityOfService = .userInteractive
            thread.start()
        }
        while state.ready.load(ordering: .acquiring) != workerCount - 1 {}
    }

    deinit {
        state.stopped.store(true, ordering: .releasing)
        while state.exited.load(ordering: .acquiring) != workerCount - 1 {}
    }

    func execute(_ job: SimulationJob) {
        guard job.count > 0 else { return }
        guard workerCount > 1 else { job.run(0..<job.count); return }
        let batchCount = min(job.count, workerCount * batchesPerWorker, 65_535)
        state.job = job
        state.remaining.store(batchCount, ordering: .relaxed)
        // Epoch prevents a delayed claim from an earlier dispatch claiming a new job.
        state.epoch &+= 1
        let ticket = UInt64(state.epoch) << 32 | UInt64(batchCount) << 16
        state.ticket.store(ticket, ordering: .releasing)
        while state.remaining.load(ordering: .acquiring) != 0 {
            state.claimAndRun()
        }
        state.job = nil
    }

    private final class State: @unchecked Sendable {
        // Ticket: epoch (32 bits), batch count (16), next batch (16).
        let ticket = Atomic<UInt64>(0)
        let remaining = Atomic<Int>(0)
        let ready = Atomic<Int>(0)
        let exited = Atomic<Int>(0)
        let stopped = Atomic<Bool>(false)
        var epoch: UInt32 = 0 // Owner only.
        // Read only after successfully claiming a batch. Immutable until all jobs complete.
        var job: SimulationJob?

        func work() {
            ready.wrappingAdd(1, ordering: .releasing)
            while !stopped.load(ordering: .acquiring) {
                claimAndRun()
            }
            exited.wrappingAdd(1, ordering: .acquiringAndReleasing)
        }

        @inline(__always)
        func claimAndRun() {
            let value = ticket.load(ordering: .acquiring)
            let index = Int(value & 0xffff)
            let batchCount = Int((value >> 16) & 0xffff)
            guard index < batchCount else { return }
            guard ticket.compareExchange(expected: value, desired: value + 1,
                                         ordering: .acquiringAndReleasing).exchanged else { return }
            do {
                let job = job!
                let start = job.count * index / batchCount
                let end = job.count * (index + 1) / batchCount
                job.run(start..<end)
            }
            // Release every write and acquire earlier completions before publishing ours.
            remaining.wrappingSubtract(1, ordering: .acquiringAndReleasing)
        }
    }
}
