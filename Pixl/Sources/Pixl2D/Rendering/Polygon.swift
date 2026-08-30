/// Mutable, value-semantic polygon-backed renderable content.
public struct Polygon: Renderable, Equatable, Sendable {
    /// Immutable local-space polygon geometry.
    public var geometry: Polygon2D
    /// Base colour source supplied to the material.
    public var paint: Paint

    public typealias Transform = Transform2D
    public typealias Bounds = Rect

    /// Local-space bounds enclosing the polygon geometry.
    public var bounds: Rect { geometry.bounds }

    /// Creates renderable polygon content from reusable geometry.
    public init(
        _ geometry: Polygon2D,
        paint: Paint = .color(.white)
    ) {
        self.geometry = geometry
        self.paint = paint
    }

    /// Creates renderable polygon content from boundary vertices.
    public init<Vertices: Collection>(
        _ vertices: Vertices,
        paint: Paint = .color(.white)
    ) where Vertices.Element == Vec2 {
        self.init(Polygon2D(vertices), paint: paint)
    }

    /// Creates renderable polygon content from boundary vertices.
    public init(
        _ vertices: Vec2...,
        paint: Paint = .color(.white)
    ) {
        self.init(Polygon2D(vertices), paint: paint)
    }

    /// Creates a centred right triangle of the supplied size.
    ///
    /// The vertical edge lies on the local right side. Use the submission
    /// transform to mirror the triangle into other orientations.
    public init(
        triangle size: Size,
        paint: Paint = .color(.white)
    ) {
        precondition(
            size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0,
            "Polygon triangle size must be finite and positive"
        )
        let halfSize = size * 0.5
        self.init(
            Polygon2D(
                Vec2(-halfSize.x, -halfSize.y),
                Vec2(halfSize.x, -halfSize.y),
                Vec2(halfSize.x, halfSize.y)
            ),
            paint: paint
        )
    }
}
