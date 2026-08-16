import Swift

public struct PointLOD: Sendable {
    public let isEnabled: Bool
    public let activationCount: Int
    public let maximumVisibleCount: Int
    public let tileSize: Int
    public let targetPointsPerPixel: Float

    public init(
        isEnabled: Bool = true,
        activationCount: Int = 500_000,
        maximumVisibleCount: Int = 1_000_000,
        tileSize: Int = 16,
        targetPointsPerPixel: Float = 1
    ) {
        precondition(activationCount >= 0)
        precondition(activationCount <= Int(UInt32.max))
        precondition(maximumVisibleCount > 0)
        precondition(maximumVisibleCount <= Int(UInt32.max))
        precondition(tileSize > 0)
        precondition(tileSize <= Int(UInt32.max))
        precondition(targetPointsPerPixel > 0)
        self.isEnabled = isEnabled
        self.activationCount = activationCount
        self.maximumVisibleCount = maximumVisibleCount
        self.tileSize = tileSize
        self.targetPointsPerPixel = targetPointsPerPixel
    }
}
