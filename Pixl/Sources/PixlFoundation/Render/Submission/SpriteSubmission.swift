import PixlPlatform
import Swift

/// Primitive, camera-independent CPU snapshot of one submitted sprite.
///
/// Execution lowers this public descriptor into compact ordinal-aligned
/// streams; it is neither a Pixl2D authoring value nor the GPU upload ABI.
public struct SpriteSubmission: Sendable {
    /// World-space minimum used for culling.
    public let boundsMinimum: SIMD2<Float>
    /// World-space maximum used for culling.
    public let boundsMaximum: SIMD2<Float>
    /// Logical identity of the sampled texture.
    public let texture: TextureResourceID
    /// Normalized texture-coordinate origin.
    public let textureCoordinateOrigin: SIMD2<Float>
    /// Normalized texture-coordinate scale.
    public let textureCoordinateScale: SIMD2<Float>
    /// First scaled model-transform column.
    public let transformX: SIMD2<Float>
    /// Second scaled model-transform column.
    public let transformY: SIMD2<Float>
    /// Model-transform translation.
    public let transformTranslation: SIMD2<Float>
    /// Packed eight-bit RGBA tint.
    public let tintRGBA8: UInt32
    /// Complete texture-sampling state.
    public let sampler: SamplerDescriptor
    /// Fixed-function colour composition.
    public let blendMode: BlendMode
    /// Coarse ordering layer. Lower values render first.
    public let layer: UInt32
    /// Ordering within `layer`. Equal values preserve submission order.
    public let order: UInt32

    /// Creates a complete camera-independent sprite submission.
    /// - Parameters:
    ///   - boundsMinimum: World-space culling minimum.
    ///   - boundsMaximum: World-space culling maximum.
    ///   - texture: Logical sampled-texture identity.
    ///   - textureCoordinateOrigin: Normalized source-region origin.
    ///   - textureCoordinateScale: Normalized source-region scale.
    ///   - transformX: First scaled model-transform column.
    ///   - transformY: Second scaled model-transform column.
    ///   - transformTranslation: Model-transform translation.
    ///   - tintRGBA8: Packed eight-bit RGBA tint.
    ///   - sampler: Complete texture-sampling state.
    ///   - blendMode: Fixed-function colour composition.
    ///   - layer: Coarse ordering layer.
    ///   - order: Ordering within `layer`.
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
