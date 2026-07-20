import Swift

/// Element stride and advancement rule for one vertex buffer slot.
public struct VertexBufferLayout: Hashable, Sendable {
    /// Vertex buffer slot described by this layout.
    public let bufferIndex: UInt32
    /// Byte distance between consecutive elements.
    public let stride: UInt64
    /// Whether elements advance per vertex or per instance.
    public let stepMode: VertexStepMode

    /// Creates a vertex buffer layout.
    /// - Parameters:
    ///   - bufferIndex: Vertex buffer slot described by this layout.
    ///   - stride: Positive byte distance between elements.
    ///   - stepMode: Frequency at which the shader advances to the next element.
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
