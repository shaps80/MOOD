import Pixl

extension Sound {
    public static let jump = Sound(id: .jump)
}

extension SoundAsset {
    public static let jump: SoundAsset = .init(
        id: .jump,
        path: "assets/audio/jump.wav"
    )
}
