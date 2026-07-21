import PixlGraphics
import Swift

/// A rectangular pixel region within one texture asset.
///
/// Source coordinates use a top-left origin, matching image files and sprite
/// sheet authoring tools.
public struct TextureRegion {
    /// Texture asset containing the region.
    public let asset: TextureAsset
    /// Pixel rectangle within `asset`, measured from its top-left corner.
    public let source: Rect

    /// Creates a region covering the entire texture asset.
    /// - Parameter asset: Texture asset covered by the region.
    public init(asset: TextureAsset) {
        self.asset = asset
        source = Rect(
            x: 0,
            y: 0,
            width: Float(asset.size.x),
            height: Float(asset.size.y)
        )
    }

    /// Creates a region from a pixel rectangle within the texture asset.
    /// - Parameters:
    ///   - asset: Texture asset containing the region.
    ///   - source: Positive pixel rectangle fully contained within `asset`.
    public init(asset: TextureAsset, source: Rect) {
        precondition(
            source.minX >= 0 && source.minY >= 0,
            "Texture region origin must be nonnegative"
        )
        precondition(
            source.size.x > 0 && source.size.y > 0,
            "Texture region size must be greater than zero"
        )
        precondition(
            source.maxX <= Float(asset.size.x),
            "Texture region exceeds texture width"
        )
        precondition(
            source.maxY <= Float(asset.size.y),
            "Texture region exceeds texture height"
        )

        self.asset = asset
        self.source = source
    }
}

package extension TextureRegion {
    var textureCoordinates: TextureCoordinates {
        let textureSize = asset.size
        return TextureCoordinates(
            origin: SIMD2(
                Float(source.minX / Float(textureSize.x)),
                Float(source.minY / Float(textureSize.y))
            ),
            scale: SIMD2(
                Float(source.size.x / Float(textureSize.x)),
                Float(source.size.y / Float(textureSize.y))
            )
        )
    }
}
