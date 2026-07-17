import PixlGraphics
import PixlPlatform
import Swift

enum PNGDecoder {
    static func decode(
        _ bytes: [UInt8],
        path: AssetPath
    ) throws(AssetError) -> DecodedTexture {
        guard path.value.lowercased().hasSuffix(".png") else {
            throw .unsupportedTexture(path.value)
        }

        do {
            let image = try PNGImage(decoding: bytes)
            return DecodedTexture(
                width: image.width,
                height: image.height,
                bytes: image.rgba8
            )
        } catch {
            throw .invalidTexture(path.value)
        }
    }
}
