import Pixl2D

public struct Sprite {
    public var region: TextureRegion
    public var isFlipped: Bool = false

    public var asset: TextureAsset {
        region.asset
    }

    public init(region: TextureRegion) {
        self.region = region
    }

    public init(named name: String, context: GameContext) throws {
        let asset = try context.assets.load(texture: name)
        region = TextureRegion(asset: asset)
    }
}
