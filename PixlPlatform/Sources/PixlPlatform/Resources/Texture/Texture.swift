import Swift

/// An opaque handle to a GPU texture allocation.
public struct Texture: Hashable, Sendable {
    package let id: ResourceID
    /// Description of the complete texture allocation.
    public let descriptor: TextureDescriptor

    package init(
        id: ResourceID,
        descriptor: TextureDescriptor
    ) {
        self.id = id
        self.descriptor = descriptor
    }
}
