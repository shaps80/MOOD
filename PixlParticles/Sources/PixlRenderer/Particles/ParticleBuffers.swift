import Swift

/// Shared simulation streams. Positions are four-particle xyz Float32 batches;
/// displacement words pack signed ten-bit xyz components (bits 0, 10, 20).
/// Colours index a premultiplied linear HDR float4 palette using UInt16.
public struct ParticleBuffers {
    public let capacity: Int
    public let displacements: HostBuffer
    public let displacementScale: Float
    public let currentPositions: HostBuffer
    public let colorIndices: HostBuffer
    public let colorPalette: HostBuffer
    public let ids: HostBuffer

    public init(
        capacity: Int,
        displacements: HostBuffer,
        displacementScale: Float,
        currentPositions: HostBuffer,
        colorIndices: HostBuffer,
        colorPalette: HostBuffer,
        ids: HostBuffer
    ) {
        self.capacity = capacity
        self.displacements = displacements
        self.displacementScale = displacementScale
        self.currentPositions = currentPositions
        self.colorIndices = colorIndices
        self.colorPalette = colorPalette
        self.ids = ids
    }
}
