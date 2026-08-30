import PixlPlatform

package enum PolygonPaintKind: UInt32, Sendable {
    case color
    case gradient
    case texture
}

/// Camera-independent snapshot of one submitted indexed polygon.
package struct PolygonSubmission {
    package let boundsMinimum: SIMD2<Float>
    package let boundsMaximum: SIMD2<Float>
    package let geometry: UInt32
    package let transformX: SIMD2<Float>
    package let transformY: SIMD2<Float>
    package let transformTranslation: SIMD2<Float>
    package let paintKind: PolygonPaintKind
    /// Solid colour, gradient placement, or texture-coordinate mapping.
    package let paintParameters: SIMD4<Float>
    package let color: SIMD4<Float>
    package let gradientSlot: UInt32
    package let gradientPlacement: UInt32
    package let texture: TextureResourceID?
    package let sampler: SamplerDescriptor
    package let blendMode: BlendMode
    package let layer: UInt32
    package let order: UInt32

    package init(
        boundsMinimum: SIMD2<Float>,
        boundsMaximum: SIMD2<Float>,
        geometry: UInt32,
        transformX: SIMD2<Float>,
        transformY: SIMD2<Float>,
        transformTranslation: SIMD2<Float>,
        paintKind: PolygonPaintKind,
        paintParameters: SIMD4<Float>,
        color: SIMD4<Float> = .zero,
        gradientSlot: UInt32 = .max,
        gradientPlacement: UInt32 = 0,
        texture: TextureResourceID? = nil,
        sampler: SamplerDescriptor = .init(),
        blendMode: BlendMode,
        layer: UInt32,
        order: UInt32
    ) {
        self.boundsMinimum = boundsMinimum
        self.boundsMaximum = boundsMaximum
        self.geometry = geometry
        self.transformX = transformX
        self.transformY = transformY
        self.transformTranslation = transformTranslation
        self.paintKind = paintKind
        self.paintParameters = paintParameters
        self.color = color
        self.gradientSlot = gradientSlot
        self.gradientPlacement = gradientPlacement
        self.texture = texture
        self.sampler = sampler
        self.blendMode = blendMode
        self.layer = layer
        self.order = order
    }
}
