import Swift

public struct VertexAttribute: Hashable, Sendable {
    public let location: UInt32
    public let bufferIndex: UInt32
    public let format: VertexFormat
    public let offset: UInt64

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
