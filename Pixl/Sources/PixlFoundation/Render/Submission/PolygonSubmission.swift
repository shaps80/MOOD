import PixlPlatform

/// Camera-independent snapshot of one submitted indexed polygon.
package struct PolygonSubmission {
    package let boundsMinimum: SIMD2<Float>
    package let boundsMaximum: SIMD2<Float>
    package let geometry: UInt32
    package let transformX: SIMD2<Float>
    package let transformY: SIMD2<Float>
    package let transformTranslation: SIMD2<Float>
    package let color: SIMD4<Float>
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
        color: SIMD4<Float>,
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
        self.color = color
        self.blendMode = blendMode
        self.layer = layer
        self.order = order
    }
}
