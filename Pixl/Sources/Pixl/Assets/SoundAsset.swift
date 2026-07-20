import PixlPlatform
import Swift

/// A cached resident sound loaded from the game's asset source.
public final class SoundAsset: Hashable {
    /// Normalized source-relative path used to load this sound.
    public let path: String
    let sound: Sound

    init(path: AssetPath, sound: Sound) {
        self.path = path.value
        self.sound = sound
    }

    /// Compares cached asset identity.
    /// - Parameters:
    ///   - lhs: First sound asset.
    ///   - rhs: Second sound asset.
    /// - Returns: `true` when both references identify the same cached asset.
    public static func == (
        lhs: SoundAsset,
        rhs: SoundAsset
    ) -> Bool {
        lhs === rhs
    }

    /// Hashes cached asset identity.
    /// - Parameter hasher: Hasher receiving this asset's identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
