import PixlPlatform

/// Geometry and style selected by one immediate primitive submission.
public enum PrimitiveKind: UInt32, BitwiseCopyable, Sendable {
    case rectFill
    case rectStroke
    case ellipseFill
    case ellipseStroke
}

/// Camera-independent snapshot of one immediate two-dimensional primitive.
public struct PrimitiveSubmission: Sendable {
    public let boundsMinimum: SIMD2<Float>
    public let boundsMaximum: SIMD2<Float>
    public let transformX: SIMD2<Float>
    public let transformY: SIMD2<Float>
    public let transformTranslation: SIMD2<Float>
    public let origin: SIMD2<Float>
    public let size: SIMD2<Float>
    public let color: SIMD4<Float>
    public let width: Float
    public let kind: PrimitiveKind
    public let layer: UInt32
    public let order: UInt32

    public init(
        boundsMinimum: SIMD2<Float>,
        boundsMaximum: SIMD2<Float>,
        transformX: SIMD2<Float>,
        transformY: SIMD2<Float>,
        transformTranslation: SIMD2<Float>,
        origin: SIMD2<Float>,
        size: SIMD2<Float>,
        color: SIMD4<Float>,
        width: Float,
        kind: PrimitiveKind,
        layer: UInt32,
        order: UInt32
    ) {
        self.boundsMinimum = boundsMinimum
        self.boundsMaximum = boundsMaximum
        self.transformX = transformX
        self.transformY = transformY
        self.transformTranslation = transformTranslation
        self.origin = origin
        self.size = size
        self.color = color
        self.width = width
        self.kind = kind
        self.layer = layer
        self.order = order
    }
}
