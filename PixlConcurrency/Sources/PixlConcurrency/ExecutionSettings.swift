import Swift

public struct ExecutionSettings: Hashable, Sendable {
    public enum LaneCount: Hashable, Sendable {
        case automatic
        case fixed(Int)
    }

    public var laneCount: LaneCount

    public init(laneCount: LaneCount = .automatic) {
        self.laneCount = laneCount
    }

    func resolvedLaneCount(for topology: ExecutionTopology) -> Int {
#if os(WASI)
        1
#else
        switch laneCount {
        case .fixed(let count):
            precondition(count > 0)
            return count
        case .automatic:
            return max(
                1,
                topology.performanceProcessorCount
                    ?? topology.availableProcessorCount
            )
        }
#endif
    }
}
