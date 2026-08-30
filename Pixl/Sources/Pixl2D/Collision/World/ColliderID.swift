/// Stable opaque identity for one collider owned by a collision world.
public struct ColliderID: Hashable, Sendable {
    package let index: Int32
    package let generation: UInt32
}
