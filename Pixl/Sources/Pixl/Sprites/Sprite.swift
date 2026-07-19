import Pixl2D

extension Sprite {
    public init(
        named name: String,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: name)
        self.init(region: TextureRegion(asset: asset))
    }
}
