/// Triangle geometry defined by three local points.
public struct TriangleShape: Hashable, Sendable {
    /// First vertex.
    public let a: Vec2
    /// Second vertex.
    public let b: Vec2
    /// Third vertex.
    public let c: Vec2
    /// Creates a canonical unit triangle.
    public init() { self.init(a: .init(0, 0.5), b: .init(-0.5, -0.5), c: .init(0.5, -0.5)) }
    /// Creates a triangle from three non-collinear finite points.
    /// - Parameters:
    ///   - a: First local vertex.
    ///   - b: Second local vertex.
    ///   - c: Third local vertex.
    public init(a: Vec2, b: Vec2, c: Vec2) {
        precondition([a.x, a.y, b.x, b.y, c.x, c.y].allSatisfy(\.isFinite))
        precondition((b.x - a.x) * (c.y - a.y) != (b.y - a.y) * (c.x - a.x))
        self.a = a; self.b = b; self.c = c
    }
    /// Canonical unit triangle.
    public static var triangle: Self { .init() }
    /// Triangle defined by three local vertices.
    /// - Parameters:
    ///   - a: First finite vertex.
    ///   - b: Second finite vertex.
    ///   - c: Third finite vertex forming nonzero area.
    public static func triangle(_ a: Vec2, _ b: Vec2, _ c: Vec2) -> Self { .init(a: a, b: b, c: c) }
}
