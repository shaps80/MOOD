import Swift

public struct ParticleBuffers {
    public let capacity: Int
    public let previousPositions: HostBuffer
    public let currentPositions: HostBuffer
    public let colors: HostBuffer
    public let ids: HostBuffer

    public init(
        capacity: Int,
        previousPositions: HostBuffer,
        currentPositions: HostBuffer,
        colors: HostBuffer,
        ids: HostBuffer
    ) {
        self.capacity = capacity
        self.previousPositions = previousPositions
        self.currentPositions = currentPositions
        self.colors = colors
        self.ids = ids
    }
}
