import PixlPlatform
import Swift

/// Analytic formula selected by one shape submission.
public enum ShapeKind: UInt32, Hashable, Sendable {
    /// Signed distance to a circle.
    case circle
    /// Signed distance to an axis-aligned rectangle.
    case rectangle
    /// Distance to a finite segment.
    case segment
    /// Signed distance to a rhombus.
    case rhombus
    /// Signed distance to an isosceles trapezoid.
    case trapezoid
    /// Signed distance to a parallelogram.
    case parallelogram
    /// Signed distance to an equilateral triangle.
    case equilateralTriangle
    /// Signed distance to an isosceles triangle.
    case isoscelesTriangle
    /// Signed distance to a point-defined triangle.
    case triangle
    /// Signed distance to an uneven capsule.
    case unevenCapsule
    /// Signed distance to a regular pentagon.
    case pentagon
    /// Signed distance to a regular hexagon.
    case hexagon
    /// Signed distance to a regular octagon.
    case octagon
    /// Signed distance to a hexagram.
    case hexagram
    /// Signed distance to a regular star.
    case star
    /// Signed distance to a circular sector.
    case pie
    /// Signed distance to a cut disk.
    case cutDisk
    /// Distance to a finite circular arc.
    case arc
    /// Signed distance to a directionally cut ring.
    case ring
    /// Signed distance to a horseshoe.
    case horseshoe
    /// Signed distance to a vesica.
    case vesica
    /// Signed distance to a crescent moon.
    case moon
    /// Signed distance to a rounded cross.
    case roundedCross
    /// Signed distance to an egg.
    case egg
    /// Signed distance to a heart.
    case heart
    /// Signed distance to an orthogonal cross.
    case cross
    /// Signed distance to a rounded X.
    case roundedX
    /// Signed distance to an ellipse.
    case ellipse
    /// Distance to a clipped parabola.
    case parabola
    /// Signed distance to a parabolic segment.
    case parabolaSegment
    /// Distance to a quadratic Bézier.
    case quadraticBezier
    /// Signed distance to a blobby cross.
    case blobbyCross
    /// Signed distance to a tunnel arch.
    case tunnel
    /// Signed distance to a staircase.
    case stairs
    /// Signed distance to a quadratic circle.
    case quadraticCircle
    /// Distance to a clipped hyperbola.
    case hyperbola
    /// Distance to a stylized S.
    case coolS
    /// Signed distance to a waved ring.
    case circleWave
}

/// Primitive, camera-independent CPU snapshot of one submitted analytic shape.
public struct ShapeSubmission: Sendable {
    /// World-space culling minimum.
    public let boundsMinimum: SIMD2<Float>
    /// World-space culling maximum.
    public let boundsMaximum: SIMD2<Float>
    /// First scaled model-transform column.
    public let transformX: SIMD2<Float>
    /// Second scaled model-transform column.
    public let transformY: SIMD2<Float>
    /// Model-transform translation.
    public let transformTranslation: SIMD2<Float>
    /// Local half extent of the submitted quad, including outward stroke.
    public let quadHalfExtent: SIMD2<Float>
    /// Formula-specific local-space parameters.
    public let parameters: SIMD4<Float>
    /// Additional parameters used only by point-defined formulas.
    public let extendedParameters: SIMD4<Float>
    /// Premultiplied interior colour.
    public let fillColor: SIMD4<Float>
    /// Registered gradient row, or `UInt32.max` for a solid fill.
    public let gradientSlot: UInt32
    /// Local start and end points for gradient projection.
    public let gradientLine: SIMD4<Float>
    /// Gradient placement: `0` linear, `1` radial, or `2` angular.
    public let gradientPlacement: UInt32
    /// Premultiplied stroke colour.
    public let strokeColor: SIMD4<Float>
    /// Analytic formula.
    public let kind: ShapeKind
    /// Stroke width in local units.
    public let strokeWidth: Float
    /// Stroke alignment encoded as `-1` inside, `0` centred, or `1` outside.
    public let strokeAlignment: Float
    /// `1` for smooth analytic coverage; `0` for a hard edge.
    public let smoothAntialiasing: Float
    /// Outward analytic rounding radius in local units.
    public let rounding: Float
    /// Fixed-function colour composition.
    public let blendMode: BlendMode
    /// Coarse ordering layer.
    public let layer: UInt32
    /// Ordering within `layer`.
    public let order: UInt32

    /// Creates a complete camera-independent analytic-shape submission.
    /// - Parameters:
    ///   - boundsMinimum: World-space culling minimum.
    ///   - boundsMaximum: World-space culling maximum.
    ///   - transformX: First scaled model-transform column.
    ///   - transformY: Second scaled model-transform column.
    ///   - transformTranslation: Model-transform translation.
    ///   - quadHalfExtent: Local quad half extent, including outward stroke.
    ///   - parameters: Formula-specific local-space parameters.
    ///   - extendedParameters: Additional point-defined formula parameters.
    ///   - fillColor: Premultiplied interior colour.
    ///   - gradientSlot: Registered gradient row, or `UInt32.max` for solid fill.
    ///   - gradientLine: Local gradient start and end points.
    ///   - gradientPlacement: Encoded linear, radial, or angular placement.
    ///   - strokeColor: Premultiplied stroke colour.
    ///   - kind: Analytic formula.
    ///   - strokeWidth: Stroke width in local units.
    ///   - strokeAlignment: Encoded inside, centred, or outside alignment.
    ///   - smoothAntialiasing: `1` for smooth coverage; `0` for hard coverage.
    ///   - rounding: Outward analytic rounding radius in local units.
    ///   - blendMode: Fixed-function colour composition.
    ///   - layer: Coarse ordering layer.
    ///   - order: Ordering within `layer`.
    public init(
        boundsMinimum: SIMD2<Float>,
        boundsMaximum: SIMD2<Float>,
        transformX: SIMD2<Float>,
        transformY: SIMD2<Float>,
        transformTranslation: SIMD2<Float>,
        quadHalfExtent: SIMD2<Float>,
        parameters: SIMD4<Float>,
        extendedParameters: SIMD4<Float> = .zero,
        fillColor: SIMD4<Float>,
        gradientSlot: UInt32 = .max,
        gradientLine: SIMD4<Float> = .zero,
        gradientPlacement: UInt32 = 0,
        strokeColor: SIMD4<Float>,
        kind: ShapeKind,
        strokeWidth: Float,
        strokeAlignment: Float,
        smoothAntialiasing: Float,
        rounding: Float = 0,
        blendMode: BlendMode,
        layer: UInt32,
        order: UInt32
    ) {
        self.boundsMinimum = boundsMinimum
        self.boundsMaximum = boundsMaximum
        self.transformX = transformX
        self.transformY = transformY
        self.transformTranslation = transformTranslation
        self.quadHalfExtent = quadHalfExtent
        self.parameters = parameters
        self.extendedParameters = extendedParameters
        self.fillColor = fillColor
        self.gradientSlot = gradientSlot
        self.gradientLine = gradientLine
        self.gradientPlacement = gradientPlacement
        self.strokeColor = strokeColor
        self.kind = kind
        self.strokeWidth = strokeWidth
        self.strokeAlignment = strokeAlignment
        self.smoothAntialiasing = smoothAntialiasing
        self.rounding = rounding
        self.blendMode = blendMode
        self.layer = layer
        self.order = order
    }
}
