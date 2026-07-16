import PixlPlatform

public extension RenderPassEncoder {
    func setFragmentTexture(
        _ asset: TextureAsset,
        index: UInt32
    ) {
        setFragmentTexture(asset.texture, index: index)
    }
}
