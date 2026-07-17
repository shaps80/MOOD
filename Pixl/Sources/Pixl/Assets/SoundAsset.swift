import PixlPlatform
import Swift

public final class SoundAsset: Hashable {
    public let path: String
    let sound: Sound

    init(path: AssetPath, sound: Sound) {
        self.path = path.value
        self.sound = sound
    }

    public static func == (
        lhs: SoundAsset,
        rhs: SoundAsset
    ) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
