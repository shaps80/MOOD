/// Opaque identity for an entity stored by a ``World``.
public struct EntityID: Hashable, Sendable {
    let storeIndex: UInt32
    let slotIndex: UInt32
    let generation: UInt32
}
