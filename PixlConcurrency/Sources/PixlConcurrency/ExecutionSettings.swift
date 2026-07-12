import Swift

package struct ExecutionSettings: Hashable, Sendable {
    package enum LaneCount: Hashable, Sendable {
        case automatic
        case fixed(Int)
    }

    package var laneCount: LaneCount

    package init(laneCount: LaneCount = .automatic) {
        self.laneCount = laneCount
    }

    func resolvedLaneCount(for topology: ExecutionTopology) -> Int {
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
    }
}
