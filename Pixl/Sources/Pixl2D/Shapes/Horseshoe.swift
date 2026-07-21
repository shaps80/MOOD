import PixlGraphics

/// Horseshoe geometry cut from a thick circular arc.
public struct Horseshoe: Hashable, Sendable {
    /// Centre-line radius.
    public let radius: Float
    /// Opening orientation.
    public let angle: Angle
    /// Straight-end length.
    public let length: Float
    /// Full band width.
    public let width: Float
    /// Creates a canonical unit horseshoe.
    public init() { self.init(radius: 0.35, angle: .degrees(120), length: 0.15, width: 0.1) }
    /// Creates a horseshoe.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - angle: Finite opening orientation.
    ///   - length: Nonnegative straight-end length.
    ///   - width: Positive full line width.
    public init(radius: Float, angle: Angle, length: Float, width: Float) {
        precondition(radius.isFinite && radius > 0 && angle.radians.isFinite)
        precondition(length.isFinite && length >= 0 && width.isFinite && width > 0)
        self.radius = radius; self.angle = angle; self.length = length; self.width = width
    }
    /// Canonical unit horseshoe geometry.
    public static var horseshoe: Self { .init() }
    /// Horseshoe geometry with explicit dimensions.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - angle: Finite opening orientation.
    ///   - length: Nonnegative straight-end length.
    ///   - width: Positive full band width.
    public static func horseshoe(radius: Float, angle: Angle, length: Float, width: Float) -> Self {
        .init(radius: radius, angle: angle, length: length, width: width)
    }
}
