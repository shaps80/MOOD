import Swift

public struct SoundAsset: Hashable, Sendable {
    public let id: SoundID
    public let path: String

    public init(id: SoundID, path: String) {
        self.id = id
        self.path = path
    }

    public static let jump = SoundAsset(
        id: .jump,
        path: "assets/audio/jump.wav"
    )
}
