public struct ExecutionTopology: Hashable, Sendable {
    public let availableProcessorCount: Int
    public let performanceProcessorCount: Int?

    public init(
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
}
