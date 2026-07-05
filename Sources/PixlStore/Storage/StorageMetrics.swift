public struct StorageMetrics: Equatable, Sendable {
    public var activeCount: Int
    public var rowCount: Int
    public var tombstoneCount: Int
    public var capacity: Int
    public var growthCount: Int
    public var compactionCount: Int

    public init(
        activeCount: Int = 0,
        rowCount: Int = 0,
        tombstoneCount: Int = 0,
        capacity: Int = 0,
        growthCount: Int = 0,
        compactionCount: Int = 0
    ) {
        self.activeCount = activeCount
        self.rowCount = rowCount
        self.tombstoneCount = tombstoneCount
        self.capacity = capacity
        self.growthCount = growthCount
        self.compactionCount = compactionCount
    }
}

