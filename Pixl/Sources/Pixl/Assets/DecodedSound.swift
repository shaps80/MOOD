import PixlPlatform
import Swift

struct DecodedSound: Sendable {
    let samples: [Float]
    let descriptor: SoundDescriptor
}

typealias SoundDecode = @Sendable (
    [UInt8],
    AssetPath
) throws(AssetError) -> DecodedSound
