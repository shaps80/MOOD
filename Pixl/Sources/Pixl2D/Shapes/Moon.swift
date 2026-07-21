/// Crescent produced by subtracting one disk from another.
public struct Moon: Hashable, Sendable {
    /// Outer disk radius.
    public let radius: Double
    /// Subtracted disk radius.
    public let cutoutRadius: Double
    /// Horizontal cutout offset.
    public let offset: Double
    /// Creates a canonical unit crescent moon.
    public init() { self.init(radius: 0.5, cutoutRadius: 0.45, offset: 0.2) }
    /// Creates a crescent moon.
    /// - Parameters:
    ///   - radius: Positive outer radius.
    ///   - cutoutRadius: Positive cutout radius.
    ///   - offset: Positive finite horizontal cutout offset.
    public init(radius: Double, cutoutRadius: Double, offset: Double) {
        precondition(radius.isFinite && radius > 0 && cutoutRadius.isFinite && cutoutRadius > 0)
        precondition(offset.isFinite && offset > 0)
        self.radius = radius; self.cutoutRadius = cutoutRadius; self.offset = offset
    }
    /// Canonical unit crescent-moon geometry.
    public static var moon: Self { .init() }
    /// Crescent-moon geometry with explicit disks.
    /// - Parameters:
    ///   - radius: Positive outer radius.
    ///   - cutoutRadius: Positive cutout radius.
    ///   - offset: Positive horizontal cutout offset.
    public static func moon(radius: Double, cutoutRadius: Double, offset: Double) -> Self {
        .init(radius: radius, cutoutRadius: cutoutRadius, offset: offset)
    }
}
