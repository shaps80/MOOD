import Pixl

extension SoundID {
    public static let laser: Self = "laser"
    public static let hit: Self = "hit"
}

extension SoundAsset {
    public static let hit: Self = .init(
        id: .hit,
        path: "assets/audio/hit.wav"
    )

    public static let laser: Self = .init(
        id: .laser,
        path: "assets/audio/laser.wav"
    )
}
