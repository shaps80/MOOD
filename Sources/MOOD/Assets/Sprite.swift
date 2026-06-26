import Pixl

extension TextureID {
    public static let player: TextureID = "player"
}

extension SpriteAsset {
    public static let player: Self = .init(
        id: .player,
        path: "assets/sprites/player.png"
    )
}
