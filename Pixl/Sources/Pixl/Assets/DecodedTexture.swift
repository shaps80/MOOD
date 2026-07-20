import PixlGraphics
import Swift

struct DecodedTexture: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    var bytesPerRow: UInt32 {
        UInt32(width * 4)
    }

    func processing(alpha: TextureAlpha) -> Self {
        guard alpha == .premultiplied else { return self }
        var bytes = bytes
        var index = 0
        while index < bytes.count {
            let alpha = Int(bytes[index + 3])
            bytes[index] = UInt8((Int(bytes[index]) * alpha + 127) / 255)
            bytes[index + 1] = UInt8((Int(bytes[index + 1]) * alpha + 127) / 255)
            bytes[index + 2] = UInt8((Int(bytes[index + 2]) * alpha + 127) / 255)
            index += 4
        }
        return Self(width: width, height: height, bytes: bytes)
    }
}
