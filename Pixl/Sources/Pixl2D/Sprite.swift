import PixlGraphics

/// A mutable, value-semantic description of one sprite.
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
}
