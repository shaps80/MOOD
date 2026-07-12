import Swift

public struct Lane: Sendable {
    public let index: Int
    public let count: Int
    private let barrier: LaneBarrier

    public var isLeader: Bool { index == 0 }

    init(index: Int, count: Int, barrier: LaneBarrier) {
        self.index = index
        self.count = count
        self.barrier = barrier
    }

    public func partition(count itemCount: Int) -> Range<Int> {
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

    public func synchronize() {
        barrier.synchronize(participantCount: count)
    }
}
