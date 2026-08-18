import Swift

public struct PointBuffers {
    public let previousPositions: HostBuffer
    public let currentPositions: HostBuffer
    public let colors: HostBuffer
    public let ids: HostBuffer

    public init(
        previousPositions: HostBuffer,
        currentPositions: HostBuffer,
        colors: HostBuffer,
        ids: HostBuffer
    ) {
        self.previousPositions = previousPositions
        self.currentPositions = currentPositions
        self.colors = colors
        self.ids = ids
    }
}
