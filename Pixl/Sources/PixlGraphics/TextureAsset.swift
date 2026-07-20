import Swift

/// A platform-independent reference to one logical texture asset.
///
/// `alpha` records whether high-level loading premultiplied decoded RGB or
/// uploaded the decoded channels unchanged. Sprite rendering uses this metadata
/// to select compatible source-over composition automatically.
public struct TextureAsset: Hashable, Sendable {
    package let identity: UInt64

    /// Pixel dimensions of the decoded texture.
    public let size: SIMD2<Int>
    /// Alpha processing applied before the texture was uploaded.
    public let alpha: TextureAlpha

    package init(
        identity: UInt64,
        size: SIMD2<Int>,
        alpha: TextureAlpha = .premultiplied
    ) {
        precondition(identity != 0, "Texture asset identity must be nonzero")
        precondition(
            size.x > 0 && size.y > 0,
            "Texture asset size must be greater than zero"
        )
        self.identity = identity
        self.size = size
        self.alpha = alpha
    }
}
