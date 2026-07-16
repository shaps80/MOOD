import Swift

struct DecodedTexture: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    var bytesPerRow: UInt32 {
        UInt32(width * 4)
    }
}
