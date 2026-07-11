import Pixl

extension TextureID {
    public static let player: Self = "player"
}

extension SpriteAsset {
    public static let player: Self = .init(
        id: .player,
        path: "assets/sprites/player.png"
    )
}
