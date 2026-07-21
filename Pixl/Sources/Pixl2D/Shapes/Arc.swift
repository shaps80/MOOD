import PixlGraphics

/// Thick circular arc geometry.
public struct Arc: Hashable, Sendable {
    /// Centre-line radius.
    public let radius: Double
    /// Total aperture centred on local positive y.
    public let angle: Angle
    /// Full line width.
    public let width: Double
    /// Creates a canonical unit semicircular arc.
    public init() { self.init(radius: 0.4, angle: .degrees(180), width: 0.1) }
    /// Creates a circular arc.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - angle: Finite aperture strictly within `0...360` degrees.
    ///   - width: Positive full line width.
    public init(radius: Double, angle: Angle, width: Double) {
        precondition(radius.isFinite && radius > 0 && width.isFinite && width > 0)
        precondition(angle.radians.isFinite && angle.radians > 0 && angle.radians < .pi * 2)
        self.radius = radius; self.angle = angle; self.width = width
    }
    /// Canonical unit arc.
    public static var arc: Self { .init() }
    /// Explicit circular arc.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - angle: Finite aperture strictly within `0...360` degrees.
    ///   - width: Positive full line width.
    public static func arc(radius: Double, angle: Angle, width: Double) -> Self { .init(radius: radius, angle: angle, width: width) }
}
