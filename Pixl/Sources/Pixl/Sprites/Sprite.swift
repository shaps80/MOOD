import Pixl2D

public extension Sprite {
    init(
        named name: String,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: name)
        self.init(region: TextureRegion(asset: asset))
    }
}
