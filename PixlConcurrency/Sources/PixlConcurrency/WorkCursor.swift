import Atomics

package final class WorkCursor: Sendable {
    package let count: Int
    package let chunkSize: Int
    private let chunkCount: Int
    private let nextChunk = ManagedAtomic<Int>(0)

    package init(count: Int, chunkSize: Int) {
        precondition(count >= 0)
        precondition(chunkSize > 0)
        self.count = count
        self.chunkSize = chunkSize
        chunkCount = count / chunkSize + (count % chunkSize == 0 ? 0 : 1)
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

        let (divisor, divisorOverflow) = laneCount.multipliedReportingOverflow(
            by: chunksPerLane
        )
        precondition(!divisorOverflow)

        let desired = max(
            1,
            count / divisor + (count % divisor == 0 ? 0 : 1)
        )
        let alignmentRemainder = desired % alignment
        let padding = alignmentRemainder == 0 ? 0 : alignment - alignmentRemainder
        let (aligned, alignmentOverflow) = desired.addingReportingOverflow(padding)
        precondition(!alignmentOverflow)
        self.init(count: count, chunkSize: aligned)
    }

    package func claim() -> Range<Int>? {
        let chunkIndex = nextChunk.loadThenWrappingIncrement(
            ordering: .relaxed
        )
        guard chunkIndex >= 0, chunkIndex < chunkCount else { return nil }

        let lowerBound = chunkIndex * chunkSize
        let upperBound = lowerBound + min(chunkSize, count - lowerBound)
        return lowerBound..<upperBound
    }

    package func reset() {
        nextChunk.store(0, ordering: .relaxed)
    }
}
