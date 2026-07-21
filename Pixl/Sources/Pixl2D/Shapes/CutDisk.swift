/// Disk cut by a horizontal chord.
public struct CutDisk: Hashable, Sendable {
    /// Disk radius.
    public let radius: Float
    /// Signed chord height from the centre.
    public let height: Float
    /// Creates a canonical unit half disk.
    public init() { self.init(radius: 0.5, height: 0) }
    /// Creates a cut disk.
    /// - Parameters:
    ///   - radius: Positive disk radius.
    ///   - height: Finite chord height with magnitude no greater than `radius`.
    public init(radius: Float, height: Float) {
        precondition(radius.isFinite && radius > 0 && height.isFinite && abs(height) <= radius)
        self.radius = radius; self.height = height
    }
    /// Canonical unit half disk.
    public static var cutDisk: Self { .init() }
    /// Explicit cut disk.
    /// - Parameters:
    ///   - radius: Positive disk radius.
    ///   - height: Finite chord height with magnitude no greater than `radius`.
    public static func cutDisk(radius: Float, height: Float) -> Self { .init(radius: radius, height: height) }
}
