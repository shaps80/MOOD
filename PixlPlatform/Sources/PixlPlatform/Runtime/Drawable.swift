import Swift

public struct Drawable: ~Copyable {
    public let texture: Texture
    package let id: ResourceID

    package init(texture: Texture, id: ResourceID) {
        self.texture = texture
        self.id = id
    }
}
