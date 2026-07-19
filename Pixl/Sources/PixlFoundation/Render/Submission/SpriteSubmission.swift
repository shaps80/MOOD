import PixlPlatform
import Swift

/// Primitive CPU snapshot of one submitted sprite.
///
/// This is retained execution data, not a public Sprite value or GPU upload
/// layout. Stage 4 replaces its repeated material description with a compact
/// resolved key.
package struct SpriteSubmission: Sendable {
    package let texture: TextureResourceID
    package let textureCoordinateOrigin: SIMD2<Float>
    package let textureCoordinateScale: SIMD2<Float>
    package let transformX: SIMD3<Float>
    package let transformY: SIMD3<Float>
    package let transformTranslation: SIMD3<Float>
    package let sampler: SamplerDescriptor
    package let blendMode: BlendMode

    package init(
        texture: TextureResourceID,
        textureCoordinateOrigin: SIMD2<Float>,
        textureCoordinateScale: SIMD2<Float>,
        transformX: SIMD3<Float>,
        transformY: SIMD3<Float>,
        transformTranslation: SIMD3<Float>,
        sampler: SamplerDescriptor,
        blendMode: BlendMode
    ) {
        self.texture = texture
        self.textureCoordinateOrigin = textureCoordinateOrigin
        self.textureCoordinateScale = textureCoordinateScale
        self.transformX = transformX
        self.transformY = transformY
        self.transformTranslation = transformTranslation
        self.sampler = sampler
        self.blendMode = blendMode
    }
}
