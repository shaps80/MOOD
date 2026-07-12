import Swift

package struct Lane: Sendable {
    package let index: Int
    package let count: Int
    private let barrier: LaneBarrier

    package var isLeader: Bool { index == 0 }

    init(index: Int, count: Int, barrier: LaneBarrier) {
        self.index = index
        self.count = count
        self.barrier = barrier
    }

    package func range(count itemCount: Int) -> Range<Int> {
        precondition(itemCount >= 0)

        let baseCount = itemCount / count
        let remainder = itemCount % count
        let lowerBound = index * baseCount + min(index, remainder)
        let upperBound = lowerBound + baseCount + (index < remainder ? 1 : 0)
        return lowerBound..<upperBound
    }

    package func claim(from cursor: WorkCursor) -> Range<Int>? {
        cursor.claim()
    }

    package func synchronize() {
        barrier.synchronize()
    }
}
