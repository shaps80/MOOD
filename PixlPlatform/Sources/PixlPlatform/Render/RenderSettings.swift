import Swift

public struct RenderSettings: Sendable, Hashable {
    public let drawableFormat: PixelFormat
    public let framePassCapacity: UInt32
    public let bufferCapacity: UInt32
    public let textureCapacity: UInt32
    public let drawableCapacity: UInt32

    public init(
        drawableFormat: PixelFormat = .bgra8Unorm,
        framePassCapacity: UInt32 = 64,
        bufferCapacity: UInt32 = 256,
        textureCapacity: UInt32 = 256,
        drawableCapacity: UInt32 = 3
    ) {
        precondition(framePassCapacity > 0, "Frame pass capacity must be greater than zero")
        precondition(bufferCapacity > 0, "Buffer capacity must be greater than zero")
        precondition(textureCapacity > 0, "Texture capacity must be greater than zero")
        precondition(drawableCapacity > 0, "Drawable capacity must be greater than zero")

        self.drawableFormat = drawableFormat
        self.framePassCapacity = framePassCapacity
        self.bufferCapacity = bufferCapacity
        self.textureCapacity = textureCapacity
        self.drawableCapacity = drawableCapacity
    }

    public static let `default`: Self = .init()
}
