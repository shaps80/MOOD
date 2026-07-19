import Swift

/// A platform-independent reference to one logical texture asset.
public struct TextureAsset: Hashable, Sendable {
    package let identity: UInt64

    /// Pixel dimensions of the decoded texture.
    public let size: SIMD2<Int>

    package init(identity: UInt64, size: SIMD2<Int>) {
        precondition(identity != 0, "Texture asset identity must be nonzero")
        precondition(
            size.x > 0 && size.y > 0,
            "Texture asset size must be greater than zero"
        )
        self.identity = identity
        self.size = size
    }
}
