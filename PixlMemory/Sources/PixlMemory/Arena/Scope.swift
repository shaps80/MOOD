import Swift

public struct Scope<Definition: MemoryLayoutDefinition>: ~Copyable {
    private let storage: ScopeStorage

    init(storage: ScopeStorage) { self.storage = storage }
    public var statistics: MemoryStatistics { storage.statistics }

    public borrowing func acquire<Child: MemoryLayoutDefinition>(_ child: Child.Type, policy: PreparationPolicy? = nil, fileID: StaticString = #fileID, line: UInt = #line) -> Scope<Child> {
        Scope<Child>(storage: storage.acquire(child, policy: policy, source: SourceLocation(fileID: fileID, line: line)))
    }

    public borrowing func buffer<Element: BitwiseCopyable>(_ keyPath: KeyPath<Definition, Element>, fileID: StaticString = #fileID, line: UInt = #line) -> IndexedBuffer<Element> {
        storage.indexedBuffer(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public borrowing func pool<Element: BitwiseCopyable>(_ keyPath: KeyPath<Definition, Element>, fileID: StaticString = #fileID, line: UInt = #line) -> DensePool<Definition, Element> {
        storage.densePool(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public borrowing func buffer(_ keyPath: KeyPath<Definition, RawBytes>, fileID: StaticString = #fileID, line: UInt = #line) -> RawBuffer {
        storage.rawBuffer(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public consuming func release() { storage.release(cascading: true) }
    deinit { storage.release(cascading: true) }
}
