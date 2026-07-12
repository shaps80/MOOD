import PixlConcurrencyC

enum Topology {
    static var current: ExecutionTopology {
        var availableCount: Int32 = 1
        var performanceCount: Int32 = 0
        pixl_topology_query(&availableCount, &performanceCount)

        return ExecutionTopology(
            availableProcessorCount: Int(availableCount),
            performanceProcessorCount: performanceCount > 0
                ? Int(performanceCount)
                : nil
        )
    }
}
