/// Parabola clipped to a finite local rendering window.
public struct Parabola: Hashable, Sendable {
    /// Coefficient in `y = curvature × x²`.
    public let curvature: Float
    /// Finite local rendering-window size.
    public let size: Vec2
    /// Creates a canonical parabola in a unit window.
    public init() { self.init(curvature: 1, size: .one) }
    /// Creates a clipped parabola.
    /// - Parameters:
    ///   - curvature: Nonzero finite coefficient in `y = curvature × x²`.
    ///   - size: Positive finite rendering-window size.
    public init(curvature: Float, size: Vec2) {
        precondition(curvature.isFinite && curvature != 0)
        precondition(size.x.isFinite && size.x > 0 && size.y.isFinite && size.y > 0)
        self.curvature = curvature; self.size = size
    }
    /// Canonical parabola geometry in a unit window.
    public static var parabola: Self { .init() }
    /// Clipped parabola geometry.
    /// - Parameters:
    ///   - curvature: Nonzero finite parabola coefficient.
    ///   - size: Positive finite rendering-window size.
    public static func parabola(curvature: Float, size: Vec2 = .one) -> Self { .init(curvature: curvature, size: size) }
}
