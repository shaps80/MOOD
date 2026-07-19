import Pixl2D

public struct Sprite {
    public var region: TextureRegion
    public var layer: RenderLayer
    public var isFlipped: Bool = false

    public var asset: TextureAsset {
        region.asset
    }

    public init(region: TextureRegion, layer: RenderLayer = 0) {
        self.region = region
        self.layer = layer
    }

    public init(
        named name: String,
        layer: RenderLayer = 0,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: name)
        region = TextureRegion(asset: asset)
        self.layer = layer
    }
}
