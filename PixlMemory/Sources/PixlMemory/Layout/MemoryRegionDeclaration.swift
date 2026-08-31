import Swift

public struct MemoryRegionDeclaration<Layout>: @unchecked Sendable {
    public let keyPath: AnyKeyPath
    public let name: String
    public let kind: RegionStorageKind
    public let policy: PreparationPolicy?
    public let elementType: Any.Type
    public let stride: UInt64
    public let alignment: UInt64

    public init<Element>(keyPath: KeyPath<Layout, Element>, name: String, kind: RegionStorageKind, policy: PreparationPolicy?, elementType: Element.Type) {
        self.keyPath = keyPath
        self.name = name
        self.kind = kind
        self.policy = policy
        self.elementType = elementType
        stride = UInt64(Swift.MemoryLayout<Element>.stride)
        alignment = UInt64(max(1, Swift.MemoryLayout<Element>.alignment))
    }
}

public enum RegionStorageKind: Hashable, Sendable {
    case indexedBuffer
    case densePool
    case rawBuffer
}
