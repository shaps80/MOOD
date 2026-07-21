/// Curved four-lobed cross geometry.
public struct BlobbyCross: Hashable, Sendable {
    /// Positive lobe-shape parameter.
    public let height: Float
    /// Creates a canonical unit blobby cross.
    public init() { height = 0.5 }
    /// Creates a blobby cross.
    /// - Parameter height: Positive lobe-shape parameter.
    public init(height: Float) { precondition(height.isFinite && height > 0); self.height = height }
    /// Canonical unit blobby-cross geometry.
    public static var blobbyCross: Self { .init() }
    /// Blobby-cross geometry with an explicit lobe height.
    /// - Parameter height: Positive lobe-shape parameter.
    public static func blobbyCross(height: Float) -> Self { .init(height: height) }
}
