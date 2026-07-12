import Atomics

final class LaneBarrier: @unchecked Sendable {
    private static let spinCount = 1_000

    private let atomicStorage = BarrierAtomicStorage()
    private let parkCondition = Condition()

    private var arrivalCount: UnsafeAtomic<Int> {
        atomicStorage.arrivalCount
    }

    private var generation: UnsafeAtomic<Int> {
        atomicStorage.generation
    }

    private var parkedWaiterCount: UnsafeAtomic<Int> {
        atomicStorage.parkedWaiterCount
    }

    init() {}

    @inline(__always)
    func synchronize(participantCount: Int) {
        guard participantCount > 1 else { return }

        let currentGeneration = generation.load(ordering: .relaxed)
        let arrival = arrivalCount.loadThenWrappingIncrement(
            ordering: .acquiringAndReleasing
        )

        if arrival == participantCount - 1 {
            arrivalCount.store(0, ordering: .relaxed)
            generation.wrappingIncrement(ordering: .releasing)
            if parkedWaiterCount.load(ordering: .acquiring) > 0 {
                parkCondition.lock()
                parkCondition.broadcast()
                parkCondition.unlock()
            }
            return
        }

        for _ in 0..<Self.spinCount {
            if generation.load(ordering: .acquiring) != currentGeneration {
                return
            }
        }

        parkCondition.lock()
        if generation.load(ordering: .acquiring) == currentGeneration {
            parkedWaiterCount.wrappingIncrement(ordering: .releasing)
            while generation.load(ordering: .acquiring) == currentGeneration {
                parkCondition.wait()
            }
            parkedWaiterCount.wrappingDecrement(ordering: .relaxed)
        }
        parkCondition.unlock()
    }
}
