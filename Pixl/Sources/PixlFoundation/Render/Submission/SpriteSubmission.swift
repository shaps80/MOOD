import PixlPlatform
import Swift

/// Primitive, camera-independent CPU snapshot of one submitted sprite.
///
/// Execution lowers this public descriptor into compact ordinal-aligned
/// streams; it is neither a Pixl2D authoring value nor the GPU upload ABI.
public struct SpriteSubmission: Sendable {
    public let boundsMinimum: SIMD2<Float>
    public let boundsMaximum: SIMD2<Float>
    public let texture: TextureResourceID
    public let textureCoordinateOrigin: SIMD2<Float>
    public let textureCoordinateScale: SIMD2<Float>
    public let transformX: SIMD2<Float>
    public let transformY: SIMD2<Float>
    public let transformTranslation: SIMD2<Float>
    public let tintRGBA8: UInt32
    public let sampler: SamplerDescriptor
    public let blendMode: BlendMode
    public let layer: UInt32
    public let order: UInt32

    public init(
        boundsMinimum: SIMD2<Float>,
        boundsMaximum: SIMD2<Float>,
        texture: TextureResourceID,
        textureCoordinateOrigin: SIMD2<Float>,
        textureCoordinateScale: SIMD2<Float>,
        transformX: SIMD2<Float>,
        transformY: SIMD2<Float>,
        transformTranslation: SIMD2<Float>,
        tintRGBA8: UInt32 = .max,
        sampler: SamplerDescriptor,
        blendMode: BlendMode,
        layer: UInt32,
        order: UInt32
    ) {
        self.boundsMinimum = boundsMinimum
        self.boundsMaximum = boundsMaximum
        self.texture = texture
        self.textureCoordinateOrigin = textureCoordinateOrigin
        self.textureCoordinateScale = textureCoordinateScale
        self.transformX = transformX
        self.transformY = transformY
        self.transformTranslation = transformTranslation
        self.tintRGBA8 = tintRGBA8
        self.sampler = sampler
        self.blendMode = blendMode
        self.layer = layer
        self.order = order
    }
}
