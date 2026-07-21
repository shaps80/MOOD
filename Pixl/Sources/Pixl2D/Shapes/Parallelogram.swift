/// Centred parallelogram geometry.
public struct Parallelogram: Hashable, Sendable {
    /// Width in local units.
    public let width: Float
    /// Height in local units.
    public let height: Float
    /// Horizontal displacement from bottom to top.
    public let skew: Float
    /// Creates a canonical unit parallelogram.
    public init() { self.init(width: 1, height: 1, skew: 0.25) }
    /// Creates a parallelogram.
    /// - Parameters:
    ///   - width: Positive width.
    ///   - height: Positive height.
    ///   - skew: Finite horizontal displacement from bottom to top.
    public init(width: Float, height: Float, skew: Float) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0 && skew.isFinite)
        self.width = width; self.height = height; self.skew = skew
    }
    /// Canonical unit parallelogram.
    public static var parallelogram: Self { .init() }
    /// Explicit parallelogram.
    /// - Parameters:
    ///   - width: Positive width.
    ///   - height: Positive height.
    ///   - skew: Finite horizontal displacement from bottom to top.
    public static func parallelogram(width: Float, height: Float, skew: Float) -> Self {
        .init(width: width, height: height, skew: skew)
    }
}
