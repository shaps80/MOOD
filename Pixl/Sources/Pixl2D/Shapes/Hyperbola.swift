/// Hyperbola clipped to a finite local rendering window.
public struct Hyperbola: Hashable, Sendable {
    /// Positive hyperbola scale.
    public let scale: Double
    /// Finite local rendering-window size.
    public let size: Vec2
    /// Creates a canonical hyperbola in a unit window.
    public init() { self.init(scale: 0.08, size: .one) }
    /// Creates a clipped hyperbola.
    /// - Parameters:
    ///   - scale: Positive hyperbola scale.
    ///   - size: Positive finite rendering-window size.
    public init(scale: Double, size: Vec2) {
        precondition(scale.isFinite && scale > 0)
        precondition(size.x.isFinite && size.x > 0 && size.y.isFinite && size.y > 0)
        self.scale = scale; self.size = size
    }
    /// Canonical hyperbola geometry in a unit window.
    public static var hyperbola: Self { .init() }
    /// Clipped hyperbola geometry.
    /// - Parameters:
    ///   - scale: Positive hyperbola scale.
    ///   - size: Positive finite rendering-window size.
    public static func hyperbola(scale: Double, size: Vec2 = .one) -> Self { .init(scale: scale, size: size) }
}
