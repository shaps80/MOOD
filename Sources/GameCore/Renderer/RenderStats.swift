import Swift

public struct RenderStats: Equatable, Sendable {
    public var commandCount: Int
    public var primitiveCount: Int
    public var batchCount: Int
    public var visibleTileCount: Int
    public var visibleEntityCount: Int

    public init(
        commandCount: Int = 0,
        primitiveCount: Int = 0,
        batchCount: Int = 0,
        visibleTileCount: Int = 0,
        visibleEntityCount: Int = 0
    ) {
        self.commandCount = commandCount
        self.primitiveCount = primitiveCount
        self.batchCount = batchCount
        self.visibleTileCount = visibleTileCount
        self.visibleEntityCount = visibleEntityCount
    }
}
