import Swift

/// Counts produced while building a frame's render data.
///
/// These values are useful for debugging and preallocating renderer buffers.
public struct RenderStats: Equatable, Sendable {
    /// Number of high-level render commands.
    public var commandCount: Int

    /// Number of primitives after command expansion.
    public var primitiveCount: Int

    /// Number of batches after primitive batching.
    public var batchCount: Int

    /// Number of visible tile draws emitted this frame.
    public var visibleTileCount: Int

    /// Number of visible entity draws emitted this frame.
    public var visibleEntityCount: Int

    /// Creates render stats.
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
