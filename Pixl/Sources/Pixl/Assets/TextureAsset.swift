import PixlPlatform
import Swift

public final class TextureAsset: Hashable {
    public let path: String
    public private(set) var texture: Texture

    public var size: TextureSize {
        texture.descriptor.size
    }

    init(path: AssetPath, texture: Texture) {
        self.path = path.value
        self.texture = texture
    }

    func replace(with texture: Texture) -> Texture {
        let previous = self.texture
        self.texture = texture
        return previous
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
