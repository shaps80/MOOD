import Swift

/// Drawable format and fixed capacities reserved by a platform renderer.
public struct RenderSettings: Sendable, Hashable {
    /// Pixel format of platform presentation textures.
    public let drawableFormat: PixelFormat
    /// Maximum passes recorded per frame.
    public let framePassCapacity: UInt32
    /// Maximum encoder commands recorded per frame.
    public let frameCommandCapacity: UInt32
    /// Maximum frame-owned byte payload.
    public let frameByteCapacity: UInt32
    /// Maximum simultaneously live buffers.
    public let bufferCapacity: UInt32
    /// Maximum simultaneously live render pipelines.
    public let pipelineCapacity: UInt32
    /// Maximum simultaneously live samplers.
    public let samplerCapacity: UInt32
    /// Maximum simultaneously live textures.
    public let textureCapacity: UInt32
    /// Maximum simultaneously acquired drawables.
    public let drawableCapacity: UInt32

    /// Creates render-resource capacities and presentation format.
    /// - Parameters:
    ///   - drawableFormat: Pixel format of presentation textures.
    ///   - framePassCapacity: Positive maximum passes per frame.
    ///   - frameCommandCapacity: Positive maximum commands per frame.
    ///   - frameByteCapacity: Positive maximum frame-owned byte payload.
    ///   - bufferCapacity: Positive live-buffer capacity.
    ///   - pipelineCapacity: Positive live-pipeline capacity.
    ///   - samplerCapacity: Positive live-sampler capacity.
    ///   - textureCapacity: Positive live-texture capacity.
    ///   - drawableCapacity: Positive simultaneously acquired drawable capacity.
    public init(
        drawableFormat: PixelFormat = .bgra8Unorm,
        framePassCapacity: UInt32 = 64,
        frameCommandCapacity: UInt32 = 1024,
        frameByteCapacity: UInt32 = 16 * 1024,
        bufferCapacity: UInt32 = 256,
        pipelineCapacity: UInt32 = 256,
        samplerCapacity: UInt32 = 64,
        textureCapacity: UInt32 = 256,
        drawableCapacity: UInt32 = 3
    ) {
        precondition(framePassCapacity > 0, "Frame pass capacity must be greater than zero")
        precondition(frameCommandCapacity > 0, "Frame command capacity must be greater than zero")
        precondition(frameByteCapacity > 0, "Frame byte capacity must be greater than zero")
        precondition(bufferCapacity > 0, "Buffer capacity must be greater than zero")
        precondition(pipelineCapacity > 0, "Pipeline capacity must be greater than zero")
        precondition(samplerCapacity > 0, "Sampler capacity must be greater than zero")
        precondition(textureCapacity > 0, "Texture capacity must be greater than zero")
        precondition(drawableCapacity > 0, "Drawable capacity must be greater than zero")

        self.drawableFormat = drawableFormat
        self.framePassCapacity = framePassCapacity
        self.frameCommandCapacity = frameCommandCapacity
        self.frameByteCapacity = frameByteCapacity
        self.bufferCapacity = bufferCapacity
        self.pipelineCapacity = pipelineCapacity
        self.samplerCapacity = samplerCapacity
        self.textureCapacity = textureCapacity
        self.drawableCapacity = drawableCapacity
    }

    /// Standard format and capacities suitable for an ordinary game.
    public static let `default`: Self = .init()
}
