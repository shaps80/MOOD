import Atomics

package final class WorkCursor: Sendable {
    package let count: Int
    package let chunkSize: Int
    private let nextIndex = ManagedAtomic<Int>(0)

    package init(count: Int, chunkSize: Int) {
        precondition(count >= 0)
        precondition(chunkSize > 0)
        self.count = count
        self.chunkSize = chunkSize
    }

    package convenience init(
        count: Int,
        laneCount: Int,
        chunksPerLane: Int = 8,
        alignment: Int = 1
    ) {
        precondition(laneCount > 0)
        precondition(chunksPerLane > 0)
        precondition(alignment > 0)

        let divisor = laneCount * chunksPerLane
        let desired = max(1, (count + divisor - 1) / divisor)
        let aligned = ((desired + alignment - 1) / alignment) * alignment
        self.init(count: count, chunkSize: aligned)
    }

    package func claim() -> Range<Int>? {
        let lowerBound = nextIndex.loadThenWrappingIncrement(
            by: chunkSize,
            ordering: .relaxed
        )
        guard lowerBound < count else { return nil }
        return lowerBound..<min(lowerBound + chunkSize, count)
    }

    package func reset() {
        nextIndex.store(0, ordering: .relaxed)
    }
}
