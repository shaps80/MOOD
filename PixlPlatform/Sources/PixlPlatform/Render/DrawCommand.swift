import Swift

public struct DrawCommand {
    public let pipeline: RenderPipeline
    public let vertexBuffer: Buffer
    public let vertexCount: UInt32

    public init(
        pipeline: RenderPipeline,
        vertexBuffer: Buffer,
        vertexCount: UInt32
    ) {
        precondition(vertexCount > 0, "Draw vertex count must be greater than zero")

        self.pipeline = pipeline
        self.vertexBuffer = vertexBuffer
        self.vertexCount = vertexCount
    }
}
