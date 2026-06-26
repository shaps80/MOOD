import Swift

public struct SpriteAsset: Hashable, Sendable {
    public let id: TextureID
    public let path: String

    public init(id: TextureID, path: String) {
        self.id = id
        self.path = path
    }
}
