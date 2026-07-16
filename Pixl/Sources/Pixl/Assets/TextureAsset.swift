import PixlPlatform
import Swift

public final class TextureAsset: Hashable {
    public let path: String
    public let texture: Texture

    public var size: TextureSize {
        texture.descriptor.size
    }

    init(path: AssetPath, texture: Texture) {
        self.path = path.value
        self.texture = texture
    }

    public static func == (
        lhs: TextureAsset,
        rhs: TextureAsset
    ) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
