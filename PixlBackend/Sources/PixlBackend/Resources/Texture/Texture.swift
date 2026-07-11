import Swift

public struct Texture: Hashable, Sendable {
    package let id: ResourceID
    public let descriptor: TextureDescriptor

    package init(
        id: ResourceID,
        descriptor: TextureDescriptor
    ) {
        self.id = id
        self.descriptor = descriptor
    }
}
