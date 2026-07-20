import Pixl2D
import PixlGraphics

extension Sprite {
    /// Loads a texture asset and creates a sprite covering the complete image.
    /// - Parameters:
    ///   - name: Source-relative texture asset path.
    ///   - alpha: Processing applied to decoded RGB before GPU upload. The
    ///     default premultiplies colour for correct filtered transparency;
    ///     `.passthrough` preserves the decoded PNG channels.
    ///   - context: Game context whose asset cache owns the texture.
    /// - Throws: ``AssetError`` when the texture cannot be loaded or created.
    public init(
        named name: String,
        alpha: TextureAlpha = .premultiplied,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: name, alpha: alpha)
        self.init(region: TextureRegion(asset: asset))
    }
}
