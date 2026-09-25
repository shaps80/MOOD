import Foundation
import PixlProfiler
import Synchronization
#if canImport(PixlParticles)
import PixlParticles
#endif

/// One submitting thread also executes jobs. Background workers spin while active and park while suspended.
/// execute is synchronous, non-reentrant, and must only be called by its owner.
nonisolated final class SpinningJobPool: SimulationExecutor {
    let workerCount: Int
    let batchesPerWorker: Int
    private let state: State
    private let recorder: ProfileRecorder?
    var frameID: UInt64 = 0
    var isProfiling = true

    init(workerCount: Int, batchesPerWorker: Int = 4,
         recorder: ProfileRecorder? = nil, workerRecorders: [ProfileRecorder] = []) {
        self.recorder = recorder
        precondition(workerCount > 0 && batchesPerWorker > 0)
        self.workerCount = workerCount
        self.batchesPerWorker = batchesPerWorker
        let state = State()
        self.state = state
        for index in 1..<workerCount {
            let workerRecorder = workerRecorders.indices.contains(index - 1) ? workerRecorders[index - 1] : nil
            let thread = Thread { state.work(recorder: workerRecorder) }
            thread.name = "Pixl Simulation \(index)"
            thread.qualityOfService = .userInteractive
            thread.start()
        }
        while state.ready.load(ordering: .acquiring) != workerCount - 1 {}
    }

    deinit {
        state.stopped.store(true, ordering: .releasing)
        setSuspended(false)
        while state.exited.load(ordering: .acquiring) != workerCount - 1 {}
    }

    /// Owner only, between synchronous dispatches. A job automatically wakes the pool.
    func setSuspended(_ suspended: Bool) {
        guard state.suspended.load(ordering: .acquiring) != suspended else { return }
        state.parking.lock()
        state.suspended.store(suspended, ordering: .releasing)
        if !suspended { state.parking.broadcast() }
        state.parking.unlock()
    }

    func execute(_ job: SimulationJob) {
        guard job.count > 0 else { return }
        guard workerCount > 1 else { job.run(0..<job.count); return }
        let recorder = isProfiling ? self.recorder : nil
        let token = recorder?.begin(JobProfileDefinitions.dispatch(for: job.kind), correlation: frameID)
        defer { if let token { recorder?.end(token) } }
        setSuspended(false)
        state.frameID = frameID
        state.recordsJob = isProfiling
        let batchCount = min(job.count, workerCount * batchesPerWorker, 65_535)
        state.job = job
        state.remaining.store(batchCount, ordering: .relaxed)
        // Epoch prevents a delayed claim from an earlier dispatch claiming a new job.
        state.epoch &+= 1
        let ticket = UInt64(state.epoch) << 32 | UInt64(batchCount) << 16
        state.ticket.store(ticket, ordering: .releasing)
        var callerIdle: ProfileToken?
        while state.remaining.load(ordering: .acquiring) != 0 {
            state.claimAndRun(recorder: recorder, idle: &callerIdle, recordsIdle: false)
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
        let suspended = Atomic<Bool>(true)
        let parking = NSCondition()
        var frameID: UInt64 = 0 // Published with job ticket.
        var epoch: UInt32 = 0 // Owner only.
        // Read only after successfully claiming a batch. Immutable until all jobs complete.
        var recordsJob = false // Published with the job ticket.
        var job: SimulationJob?

        func work(recorder: ProfileRecorder?) {
            var idle: ProfileToken?
            ready.wrappingAdd(1, ordering: .releasing)
            while !stopped.load(ordering: .acquiring) {
                if suspended.load(ordering: .acquiring) {
                    if let idle { recorder?.end(idle) }
                    idle = nil
                    parking.lock()
                    while suspended.load(ordering: .acquiring)
                        && !stopped.load(ordering: .acquiring) {
                        parking.wait()
                    }
                    parking.unlock()
                    idle = nil
                } else {
                    claimAndRun(recorder: recorder, idle: &idle, recordsIdle: true)
                }
            }
            exited.wrappingAdd(1, ordering: .acquiringAndReleasing)
        }

        @inline(__always)
        func claimAndRun(recorder: ProfileRecorder?, idle: inout ProfileToken?, recordsIdle: Bool) {
            let value = ticket.load(ordering: .acquiring)
            let index = Int(value & 0xffff)
            let batchCount = Int((value >> 16) & 0xffff)
            guard index < batchCount else { return }
            guard ticket.compareExchange(expected: value, desired: value + 1,
                                         ordering: .acquiringAndReleasing).exchanged else { return }
            if let idle { recorder?.end(idle) }
            idle = nil
            let recorder = recordsJob ? recorder : nil
            do {
                let job = job!
                let start = job.count * index / batchCount
                let end = job.count * (index + 1) / batchCount
                let token = recorder?.begin(JobProfileDefinitions.batch(for: job.kind), correlation: frameID, detail: UInt32(index))
                job.run(start..<end)
                if let token { recorder?.end(token) }
            }
            // Release every write and acquire earlier completions before publishing ours.
            if recordsIdle { idle = recorder?.begin(JobProfileDefinitions.spin) }
            remaining.wrappingSubtract(1, ordering: .acquiringAndReleasing)
        }
    }
}
