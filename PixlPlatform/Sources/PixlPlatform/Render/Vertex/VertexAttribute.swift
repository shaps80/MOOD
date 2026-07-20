import Swift

/// One shader input read from a vertex buffer.
public struct VertexAttribute: Hashable, Sendable {
    /// Shader attribute location.
    public let location: UInt32
    /// Vertex buffer slot supplying the attribute.
    public let bufferIndex: UInt32
    /// Scalar representation and component count.
    public let format: VertexFormat
    /// Byte offset from the start of each buffer element.
    public let offset: UInt64

    /// Creates a vertex attribute description.
    /// - Parameters:
    ///   - location: Shader attribute location.
    ///   - bufferIndex: Declared vertex buffer slot supplying values.
    ///   - format: Scalar representation and component count.
    ///   - offset: Byte offset within each buffer element.
    public init(
        location: UInt32,
        bufferIndex: UInt32,
        format: VertexFormat,
        offset: UInt64
    ) {
        self.location = location
        self.bufferIndex = bufferIndex
        self.format = format
        self.offset = offset
    }
}
