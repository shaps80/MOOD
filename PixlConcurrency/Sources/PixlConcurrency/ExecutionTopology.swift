import Swift

package struct ExecutionTopology: Hashable, Sendable {
    package let availableProcessorCount: Int
    package let performanceProcessorCount: Int?

    package init(
        availableProcessorCount: Int,
        performanceProcessorCount: Int? = nil
    ) {
        precondition(availableProcessorCount > 0)
        if let performanceProcessorCount {
            precondition(performanceProcessorCount > 0)
            precondition(performanceProcessorCount <= availableProcessorCount)
        }

        self.availableProcessorCount = availableProcessorCount
        self.performanceProcessorCount = performanceProcessorCount
    }

    package static var current: ExecutionTopology {
        Topology.current
    }
}
