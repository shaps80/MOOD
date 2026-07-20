import Pixl2D

extension Sprite {
    /// Loads a texture asset and creates a sprite covering the complete image.
    /// - Parameters:
    ///   - name: Source-relative texture asset path.
    ///   - context: Game context whose asset cache owns the texture.
    /// - Throws: ``AssetError`` when the texture cannot be loaded or created.
    public init(
        named name: String,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: name)
        self.init(region: TextureRegion(asset: asset))
    }
}
