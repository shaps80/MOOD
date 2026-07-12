import Swift

public struct RenderSettings: Sendable, Hashable {
    public let drawableFormat: PixelFormat
    public let framePassCapacity: UInt32
    public let frameCommandCapacity: UInt32
    public let frameByteCapacity: UInt32
    public let bufferCapacity: UInt32
    public let pipelineCapacity: UInt32
    public let textureCapacity: UInt32
    public let drawableCapacity: UInt32

    public init(
        drawableFormat: PixelFormat = .bgra8Unorm,
        framePassCapacity: UInt32 = 64,
        frameCommandCapacity: UInt32 = 1024,
        frameByteCapacity: UInt32 = 16 * 1024,
        bufferCapacity: UInt32 = 256,
        pipelineCapacity: UInt32 = 256,
        textureCapacity: UInt32 = 256,
        drawableCapacity: UInt32 = 3
    ) {
        precondition(framePassCapacity > 0, "Frame pass capacity must be greater than zero")
        precondition(frameCommandCapacity > 0, "Frame command capacity must be greater than zero")
        precondition(frameByteCapacity > 0, "Frame byte capacity must be greater than zero")
        precondition(bufferCapacity > 0, "Buffer capacity must be greater than zero")
        precondition(pipelineCapacity > 0, "Pipeline capacity must be greater than zero")
        precondition(textureCapacity > 0, "Texture capacity must be greater than zero")
        precondition(drawableCapacity > 0, "Drawable capacity must be greater than zero")

        self.drawableFormat = drawableFormat
        self.framePassCapacity = framePassCapacity
        self.frameCommandCapacity = frameCommandCapacity
        self.frameByteCapacity = frameByteCapacity
        self.bufferCapacity = bufferCapacity
        self.pipelineCapacity = pipelineCapacity
        self.textureCapacity = textureCapacity
        self.drawableCapacity = drawableCapacity
    }

    public static let `default`: Self = .init()
}
