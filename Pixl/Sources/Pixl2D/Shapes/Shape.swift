import PixlGraphics

/// A mutable, value-semantic analytic two-dimensional shape.
///
/// Solid and gradient colours are converted to premultiplied representation
/// before normal source-over composition. Shapes render analytically, so
/// sprite texture filtering does not apply to their edges.
public struct Shape: Hashable, Sendable, Renderable {
    /// Analytic geometry rendered by the shape.
    public enum Geometry: Hashable, Sendable {
        /// Circle geometry.
        case circle(Circle)
        /// Shared local-space circle geometry used by collision and rendering.
        case circle2D(Circle2D)
        /// Rectangle geometry.
        case rectangle(Rectangle)
        /// Rectangle geometry with independent continuous corner radii.
        case unevenRoundedRectangle(UnevenRoundedRectangle)
        /// Finite line-segment geometry.
        case segment(Segment)
        /// Rhombus geometry.
        case rhombus(Rhombus)
        /// Isosceles trapezoid geometry.
        case trapezoid(Trapezoid)
        /// Parallelogram geometry.
        case parallelogram(Parallelogram)
        /// Equilateral-triangle geometry.
        case equilateralTriangle(EquilateralTriangle)
        /// Isosceles-triangle geometry.
        case isoscelesTriangle(IsoscelesTriangle)
        /// Triangle geometry defined by three points.
        case triangle(TriangleShape)
        /// Capsule geometry with independent end radii.
        case unevenCapsule(UnevenCapsule)
        /// Shared local-space equal-radius capsule geometry.
        case capsule2D(Capsule2D)
        /// Regular-pentagon geometry.
        case pentagon(Pentagon)
        /// Regular-hexagon geometry.
        case hexagon(Hexagon)
        /// Regular-octagon geometry.
        case octagon(Octagon)
        /// Six-pointed-star geometry.
        case hexagram(Hexagram)
        /// Configurable regular-star geometry.
        case star(Star)
        /// Circular-sector geometry.
        case pie(Pie)
        /// Disk cut by a horizontal chord.
        case cutDisk(CutDisk)
        /// Finite circular-arc geometry.
        case arc(Arc)
        /// Directionally cut ring geometry.
        case ring(Ring)
        /// Horseshoe geometry.
        case horseshoe(Horseshoe)
        /// Vesica-piscis geometry.
        case vesica(Vesica)
        /// Crescent-moon geometry.
        case moon(Moon)
        /// Rounded-cross geometry.
        case roundedCross(RoundedCross)
        /// Egg geometry.
        case egg(Egg)
        /// Heart geometry.
        case heart(Heart)
        /// Orthogonal-cross geometry.
        case cross(Cross)
        /// Rounded diagonal-cross geometry.
        case roundedX(RoundedX)
        /// Ellipse geometry.
        case ellipse(Ellipse)
        /// Finite clipped-parabola geometry.
        case parabola(Parabola)
        /// Filled parabolic-segment geometry.
        case parabolaSegment(ParabolaSegment)
        /// Quadratic Bézier geometry.
        case quadraticBezier(QuadraticBezier)
        /// Blobby-cross geometry.
        case blobbyCross(BlobbyCross)
        /// Tunnel-arch geometry.
        case tunnel(Tunnel)
        /// Staircase geometry.
        case stairs(Stairs)
        /// Quadratic-circle geometry.
        case quadraticCircle(QuadraticCircle)
        /// Finite clipped-hyperbola geometry.
        case hyperbola(Hyperbola)
        /// Stylized S geometry.
        case coolS(CoolS)
        /// Waved-ring geometry.
        case circleWave(CircleWave)
    }

    /// Edge coverage mode.
    public enum Antialiasing: Hashable, Sendable {
        /// Smooth analytic edge coverage.
        case smooth
        /// Hard binary edge coverage.
        case hard
    }

    /// Analytic geometry.
    public var geometry: Geometry
    /// Interior paint. Defaults to opaque white.
    public var fill: FillStyle
    /// Optional analytic boundary stroke.
    public var stroke: StrokeStyle?
    /// Edge coverage mode.
    public var antialiasing: Antialiasing
    /// Outward rounding applied to the analytic boundary, in local units.
    public var rounding: Float

    public typealias Transform = Transform2D
    public typealias Bounds = Rect

    /// Creates a circle shape.
    ///
    /// ```swift
    /// let shape = Shape(.circle(radius: 20)).fill(.red)
    /// ```
    ///
    /// - Parameter geometry: Unit or explicitly sized circle geometry.
    public init(_ geometry: Circle) {
        self.init(geometry: .circle(geometry))
    }

    /// Creates an analytic shape from reusable circle geometry.
    public init(_ geometry: Circle2D) {
        self.init(geometry: .circle2D(geometry))
    }

    /// Creates a rectangle shape.
    ///
    /// ```swift
    /// let shape = Shape(.rect, rounding: 8)
    ///     .fill(.red)
    ///     .stroke(.white, width: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - geometry: Unit or explicitly sized rectangle geometry.
    ///   - rounding: Nonnegative local-space corner radius.
    public init(_ geometry: Rectangle, rounding: Float = 0) {
        precondition(rounding.isFinite && rounding >= 0)
        self.init(geometry: .rectangle(geometry))
        self.rounding = rounding
    }

    /// Creates a rectangle shape with independent continuous corner radii.
    public init(_ geometry: UnevenRoundedRectangle) {
        self.init(geometry: .unevenRoundedRectangle(geometry))
    }

    /// Creates a segment shape. Use `Shape(.segment)` for the canonical unit segment.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Segment) { self.init(geometry: .segment(geometry)) }
    /// Creates a rhombus shape. Use `Shape(.rhombus)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Rhombus) { self.init(geometry: .rhombus(geometry)) }
    /// Creates a trapezoid shape. Use `Shape(.trapezoid)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Trapezoid) { self.init(geometry: .trapezoid(geometry)) }
    /// Creates a parallelogram shape. Use `Shape(.parallelogram)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Parallelogram) { self.init(geometry: .parallelogram(geometry)) }
    /// Creates an equilateral-triangle shape. Use `Shape(.equilateralTriangle)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: EquilateralTriangle) { self.init(geometry: .equilateralTriangle(geometry)) }
    /// Creates an isosceles-triangle shape. Use `Shape(.isoscelesTriangle)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: IsoscelesTriangle) { self.init(geometry: .isoscelesTriangle(geometry)) }
    /// Creates an arbitrary-triangle shape. Use `Shape(.triangle)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: TriangleShape) { self.init(geometry: .triangle(geometry)) }
    /// Creates an uneven-capsule shape. Use `Shape(.unevenCapsule)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: UnevenCapsule) { self.init(geometry: .unevenCapsule(geometry)) }
    /// Creates an analytic shape from reusable capsule geometry.
    public init(_ geometry: Capsule2D) { self.init(geometry: .capsule2D(geometry)) }
    /// Creates a regular-pentagon shape. Use `Shape(.pentagon)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Pentagon) { self.init(geometry: .pentagon(geometry)) }
    /// Creates a regular-hexagon shape. Use `Shape(.hexagon)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Hexagon) { self.init(geometry: .hexagon(geometry)) }
    /// Creates a regular-octagon shape. Use `Shape(.octagon)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Octagon) { self.init(geometry: .octagon(geometry)) }
    /// Creates a hexagram shape. Use `Shape(.hexagram)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Hexagram) { self.init(geometry: .hexagram(geometry)) }
    /// Creates a regular-star shape. Use `Shape(.star)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Star) { self.init(geometry: .star(geometry)) }
    /// Creates a circular-sector shape. Use `Shape(.pie)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Pie) { self.init(geometry: .pie(geometry)) }
    /// Creates a cut-disk shape. Use `Shape(.cutDisk)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: CutDisk) { self.init(geometry: .cutDisk(geometry)) }
    /// Creates an arc shape. Use `Shape(.arc)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Arc) { self.init(geometry: .arc(geometry)) }
    /// Creates a ring shape. Use `Shape(.ring)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Ring) { self.init(geometry: .ring(geometry)) }
    /// Creates a horseshoe shape. Use `Shape(.horseshoe)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Horseshoe) { self.init(geometry: .horseshoe(geometry)) }
    /// Creates a vesica shape. Use `Shape(.vesica)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Vesica) { self.init(geometry: .vesica(geometry)) }
    /// Creates a crescent-moon shape. Use `Shape(.moon)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Moon) { self.init(geometry: .moon(geometry)) }
    /// Creates a rounded-cross shape. Use `Shape(.roundedCross)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: RoundedCross) { self.init(geometry: .roundedCross(geometry)) }
    /// Creates an egg shape. Use `Shape(.egg)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Egg) { self.init(geometry: .egg(geometry)) }
    /// Creates a heart shape. Use `Shape(.heart)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Heart) { self.init(geometry: .heart(geometry)) }
    /// Creates a cross shape. Use `Shape(.cross)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Cross) { self.init(geometry: .cross(geometry)) }
    /// Creates a rounded-X shape. Use `Shape(.roundedX)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: RoundedX) { self.init(geometry: .roundedX(geometry)) }
    /// Creates an ellipse shape. Use `Shape(.ellipse)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Ellipse) { self.init(geometry: .ellipse(geometry)) }
    /// Creates a clipped parabola shape. Use `Shape(.parabola)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Parabola) { self.init(geometry: .parabola(geometry)) }
    /// Creates a filled parabolic-segment shape. Use `Shape(.parabolaSegment)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: ParabolaSegment) { self.init(geometry: .parabolaSegment(geometry)) }
    /// Creates a quadratic-Bézier shape. Use `Shape(.quadraticBezier)` for canonical control points.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: QuadraticBezier) { self.init(geometry: .quadraticBezier(geometry)) }
    /// Creates a blobby-cross shape. Use `Shape(.blobbyCross)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: BlobbyCross) { self.init(geometry: .blobbyCross(geometry)) }
    /// Creates a tunnel shape. Use `Shape(.tunnel)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Tunnel) { self.init(geometry: .tunnel(geometry)) }
    /// Creates a staircase shape. Use `Shape(.stairs)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Stairs) { self.init(geometry: .stairs(geometry)) }
    /// Creates a quadratic-circle shape. Use `Shape(.quadraticCircle)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: QuadraticCircle) { self.init(geometry: .quadraticCircle(geometry)) }
    /// Creates a clipped hyperbola shape. Use `Shape(.hyperbola)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: Hyperbola) { self.init(geometry: .hyperbola(geometry)) }
    /// Creates a stylized S shape. Use `Shape(.coolS)` for unit sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: CoolS) { self.init(geometry: .coolS(geometry)) }
    /// Creates a circle-wave shape. Use `Shape(.circleWave)` for canonical sizing.
    /// - Parameter geometry: Analytic geometry value.
    public init(_ geometry: CircleWave) { self.init(geometry: .circleWave(geometry)) }

    private init(geometry: Geometry) {
        self.geometry = geometry
        fill = .color(.white)
        stroke = nil
        antialiasing = .smooth
        rounding = 0
    }

    /// Returns a copy using a solid interior colour.
    /// - Parameter color: Interior colour.
    public func fill(_ color: Color) -> Self {
        var copy = self
        copy.fill = .color(color)
        return copy
    }

    /// Returns a copy using the supplied interior paint.
    /// - Parameter fill: Interior paint.
    public func fill(_ fill: FillStyle) -> Self {
        var copy = self
        copy.fill = fill
        return copy
    }

    /// Returns a copy using a directed linear gradient interior.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - start: Local point receiving location `0`.
    ///   - end: Local point receiving location `1`.
    public func fill(
        _ gradient: Gradient,
        from start: Vec2 = .init(-0.5, 0),
        to end: Vec2 = .init(0.5, 0)
    ) -> Self {
        fill(.gradient(.init(gradient, from: start, to: end)))
    }

    /// Returns a copy using a radial gradient interior.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - center: Local point receiving location `0`.
    ///   - radius: Positive local radius receiving location `1`.
    public func fill(
        _ gradient: Gradient,
        center: Vec2 = .zero,
        radius: Float
    ) -> Self {
        fill(.gradient(.init(gradient, center: center, radius: radius)))
    }

    /// Returns a copy using an angular gradient interior.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - center: Local point around which locations rotate.
    ///   - angle: Angle at which location `0` begins.
    public func fill(
        _ gradient: Gradient,
        center: Vec2 = .zero,
        angle: Angle
    ) -> Self {
        fill(.gradient(.init(gradient, center: center, angle: angle)))
    }

    /// Returns a copy with an analytic stroke.
    /// - Parameters:
    ///   - color: Stroke colour.
    ///   - width: Positive width in local units.
    ///   - alignment: Placement relative to the analytic boundary.
    public func stroke(
        _ color: Color,
        width: Float,
        alignment: StrokeStyle.Alignment = .center
    ) -> Self {
        var copy = self
        copy.stroke = .init(color, width: width, alignment: alignment)
        return copy
    }

    /// Returns a copy using the selected edge coverage mode.
    /// - Parameter antialiasing: Smooth or hard analytic edge coverage.
    public func antialiasing(_ antialiasing: Antialiasing) -> Self {
        var copy = self
        copy.antialiasing = antialiasing
        return copy
    }

    /// Returns a copy with its analytic boundary rounded outward.
    ///
    /// ```swift
    /// let shape = Shape(.hexagon).rounding(4)
    /// ```
    ///
    /// - Parameter radius: Nonnegative rounding radius in local units.
    public func rounding(_ radius: Float) -> Self {
        precondition(radius.isFinite && radius >= 0)
        var copy = self
        copy.rounding = radius
        return copy
    }
}
