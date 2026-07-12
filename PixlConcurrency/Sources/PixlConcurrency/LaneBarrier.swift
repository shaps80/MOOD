import Atomics

final class LaneBarrier: @unchecked Sendable {
    private let participantCount: Int
    private let arrivalCount = ManagedAtomic<Int>(0)
    private let generation = ManagedAtomic<Int>(0)
    private let parkedWaiterCount = ManagedAtomic<Int>(0)
    private let parkCondition = NativeCondition()

    init(participantCount: Int) {
        precondition(participantCount > 0)
        self.participantCount = participantCount
    }

    @inline(__always)
    func synchronize() {
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

        for _ in 0..<2_000 {
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
