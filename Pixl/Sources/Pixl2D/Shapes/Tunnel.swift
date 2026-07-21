/// Arched tunnel geometry.
public struct Tunnel: Hashable, Sendable {
    /// Full arch width.
    public let width: Float
    /// Wall height below the arch centre.
    public let height: Float
    /// Creates a canonical unit tunnel.
    public init() { self.init(width: 1, height: 1) }
    /// Creates an arched tunnel.
    /// - Parameters:
    ///   - width: Positive full width.
    ///   - height: Positive wall height below the arch centre.
    public init(width: Float, height: Float) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0)
        self.width = width; self.height = height
    }
    /// Canonical unit tunnel geometry.
    public static var tunnel: Self { .init() }
    /// Tunnel geometry with explicit dimensions.
    /// - Parameters:
    ///   - width: Positive full arch width.
    ///   - height: Positive wall height.
    public static func tunnel(width: Float, height: Float) -> Self { .init(width: width, height: height) }
}
