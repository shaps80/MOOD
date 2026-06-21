import Swift

public struct SpriteAsset: Hashable, Sendable {
    public let id: SpriteID
    public let path: String

    public init(id: SpriteID, path: String) {
        self.id = id
        self.path = path
    }

    public static let player = SpriteAsset(
        id: .player,
        path: "assets/sprites/player.png"
    )
}
