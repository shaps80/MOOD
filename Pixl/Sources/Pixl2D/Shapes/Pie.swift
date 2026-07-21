import PixlGraphics

/// Circular sector geometry.
public struct Pie: Hashable, Sendable {
    /// Radius.
    public let radius: Float
    /// Total aperture centred on local positive y.
    public let angle: Angle
    /// Creates a unit quarter-circle sector.
    public init() { self.init(radius: 0.5, angle: .degrees(90)) }
    /// Creates a circular sector.
    /// - Parameters:
    ///   - radius: Positive radius.
    ///   - angle: Finite aperture strictly within `0...360` degrees.
    public init(radius: Float, angle: Angle) {
        precondition(radius.isFinite && radius > 0)
        precondition(angle.radians.isFinite && angle.radians > 0 && angle.radians < .pi * 2)
        self.radius = radius; self.angle = angle
    }
    /// Canonical unit sector.
    public static var pie: Self { .init() }
    /// Explicit circular sector.
    /// - Parameters:
    ///   - radius: Positive radius.
    ///   - angle: Finite aperture strictly within `0...360` degrees.
    public static func pie(radius: Float, angle: Angle) -> Self { .init(radius: radius, angle: angle) }
}
