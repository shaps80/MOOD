import Swift

public struct PointBuffers {
    public let previousPositions: HostBuffer
    public let currentPositions: HostBuffer
    public let previousColors: HostBuffer
    public let currentColors: HostBuffer
    public let ids: HostBuffer

    public init(
        previousPositions: HostBuffer,
        currentPositions: HostBuffer,
        previousColors: HostBuffer,
        currentColors: HostBuffer,
        ids: HostBuffer
    ) {
        self.previousPositions = previousPositions
        self.currentPositions = currentPositions
        self.previousColors = previousColors
        self.currentColors = currentColors
        self.ids = ids
    }
}
