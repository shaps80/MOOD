/// Vesica piscis formed by two equal intersecting circles.
public struct Vesica: Hashable, Sendable {
    /// Source-circle radius.
    public let radius: Float
    /// Half-distance between source-circle centres.
    public let offset: Float
    /// Creates a canonical unit vesica.
    public init() { self.init(radius: 0.5, offset: 0.25) }
    /// Creates a vesica.
    /// - Parameters:
    ///   - radius: Positive source-circle radius.
    ///   - offset: Centre offset in `0..<radius`.
    public init(radius: Float, offset: Float) {
        precondition(radius.isFinite && radius > 0 && offset.isFinite && offset >= 0 && offset < radius)
        self.radius = radius; self.offset = offset
    }
    /// Canonical unit vesica geometry.
    public static var vesica: Self { .init() }
    /// Vesica geometry with explicit source circles.
    /// - Parameters:
    ///   - radius: Positive source-circle radius.
    ///   - offset: Centre offset in `0..<radius`.
    public static func vesica(radius: Float, offset: Float) -> Self { .init(radius: radius, offset: offset) }
}
