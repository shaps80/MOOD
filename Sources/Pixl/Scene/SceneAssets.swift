import Swift

public struct SceneAssets: Sendable {
    public let sprites: [SpriteAsset]
    public let sounds: [SoundAsset]

    public init(sprites: [SpriteAsset], sounds: [SoundAsset]) {
        self.sprites = sprites
        self.sounds = sounds
    }
}
