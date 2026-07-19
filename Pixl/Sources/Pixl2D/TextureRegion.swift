import PixlGraphics
import Swift

/// A rectangular pixel region within one texture asset.
///
/// Source coordinates use a top-left origin, matching image files and sprite
/// sheet authoring tools.
public struct TextureRegion {
    public let asset: TextureAsset
    public let source: Rect

    /// Creates a region covering the entire texture asset.
    public init(asset: TextureAsset) {
        self.asset = asset
        source = Rect(
            x: 0,
            y: 0,
            width: Double(asset.size.x),
            height: Double(asset.size.y)
        )
    }

    /// Creates a region from a pixel rectangle within the texture asset.
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
            source.maxX <= Double(asset.size.x),
            "Texture region exceeds texture width"
        )
        precondition(
            source.maxY <= Double(asset.size.y),
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
                Float(source.minX / Double(textureSize.x)),
                Float(source.minY / Double(textureSize.y))
            ),
            scale: SIMD2(
                Float(source.size.x / Double(textureSize.x)),
                Float(source.size.y / Double(textureSize.y))
            )
        )
    }
}
