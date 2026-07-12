import Swift

public struct VertexBufferLayout: Hashable, Sendable {
    public let bufferIndex: UInt32
    public let stride: UInt64
    public let stepMode: VertexStepMode

    public init(
        bufferIndex: UInt32,
        stride: UInt64,
        stepMode: VertexStepMode = .perVertex
    ) {
        precondition(stride > 0, "Vertex buffer stride must be greater than zero")

        self.bufferIndex = bufferIndex
        self.stride = stride
        self.stepMode = stepMode
    }
}
