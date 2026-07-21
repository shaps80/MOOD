/// Egg geometry with independently controlled lower and upper radii.
public struct Egg: Hashable, Sendable {
    /// Lower lobe radius.
    public let lowerRadius: Double
    /// Upper lobe radius.
    public let upperRadius: Double
    /// Creates a canonical unit egg.
    public init() { self.init(lowerRadius: 0.5, upperRadius: 0.3) }
    /// Creates an egg.
    /// - Parameters:
    ///   - lowerRadius: Positive lower radius.
    ///   - upperRadius: Positive upper radius no greater than `lowerRadius`.
    public init(lowerRadius: Double, upperRadius: Double) {
        precondition(lowerRadius.isFinite && lowerRadius > 0)
        precondition(upperRadius.isFinite && upperRadius > 0 && upperRadius <= lowerRadius)
        self.lowerRadius = lowerRadius; self.upperRadius = upperRadius
    }
    /// Canonical unit egg geometry.
    public static var egg: Self { .init() }
    /// Egg geometry with explicit lobe radii.
    /// - Parameters:
    ///   - lowerRadius: Positive lower radius.
    ///   - upperRadius: Positive upper radius.
    public static func egg(lowerRadius: Double, upperRadius: Double) -> Self {
        .init(lowerRadius: lowerRadius, upperRadius: upperRadius)
    }
}
