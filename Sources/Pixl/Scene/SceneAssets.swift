import Swift

public struct SceneAssets: Sendable {
    public let sprites: [SpriteAsset]
    public let sounds: [SoundAsset]

    public init(sprites: [SpriteAsset], sounds: [SoundAsset]) {
        self.sprites = sprites
        self.sounds = sounds
    }

    public init(sprites: [SpriteAsset]) {
        self.sprites = sprites
        self.sounds = []
    }

    public init(sounds: [SoundAsset]) {
        self.sprites = []
        self.sounds = sounds
    }
}
