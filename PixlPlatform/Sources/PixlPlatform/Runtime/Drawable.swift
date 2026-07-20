import Swift

/// A noncopyable frame-scoped presentation surface acquired from a ``Platform``.
public struct Drawable: ~Copyable {
    /// Transient texture available as the frame's presentation target.
    public let texture: Texture
    package let id: ResourceID

    package init(texture: Texture, id: ResourceID) {
        self.texture = texture
        self.id = id
    }
}
