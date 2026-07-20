import PixlGraphics
import PixlPlatform
import Swift

typealias TextureDecode = @Sendable (
    [UInt8],
    AssetPath
) throws(AssetError) -> DecodedTexture

struct TexturePreparation: Sendable {
    let decode: TextureDecode

    func prepare(
        _ bytes: [UInt8],
        path: AssetPath,
        alpha: TextureAlpha
    ) throws(AssetError) -> DecodedTexture {
        try decode(bytes, path).processing(alpha: alpha)
    }
}
