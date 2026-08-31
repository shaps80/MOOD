import Swift

public final class Arena<Persistent: MemoryLayoutDefinition> {
    private let storage: ArenaStorage

    public convenience init(_ persistent: Persistent.Type, layouts: any MemoryLayoutDefinition.Type..., logging: ArenaLogging = .automatic) throws {
        try self.init(name: nil, persistent: persistent, layouts: layouts, logging: logging)
    }

    public convenience init(_ name: String, persistent: Persistent.Type, layouts: any MemoryLayoutDefinition.Type..., logging: ArenaLogging = .automatic) throws {
        try self.init(name: name, persistent: persistent, layouts: layouts, logging: logging)
    }

    private init(name: String?, persistent: Persistent.Type, layouts: [any MemoryLayoutDefinition.Type], logging: ArenaLogging) throws {
        if let name, name.isEmpty { throw MemoryFailure("Arena name must not be empty") }
        let persistentRecord = try LayoutCompiler.compile(persistent)
        var records: [LayoutRecord] = []
        var registered = Set<ObjectIdentifier>()
        for layout in layouts {
            let typeID = ObjectIdentifier(layout)
            guard registered.insert(typeID).inserted else {
                throw MemoryFailure("Duplicate top-level layout '\(layout.memoryLayoutName)'")
            }
            records.append(try compileErased(layout))
        }
        storage = ArenaStorage(name: name, logging: logging, persistent: persistentRecord, layouts: records)
        storage.log(ReportFormatter.startup(storage))
    }

    public var reserved: ByteCount { ByteCount(rawValue: storage.reserved) }
    public var statistics: MemoryStatistics { storage.statistics }

    public func acquire<Definition: MemoryLayoutDefinition>(_ layout: Definition.Type, policy: PreparationPolicy? = nil, fileID: StaticString = #fileID, line: UInt = #line) -> Scope<Definition> {
        Scope(storage: storage.acquire(layout, policy: policy, source: SourceLocation(fileID: fileID, line: line)))
    }

    public func buffer<Element: BitwiseCopyable>(_ keyPath: KeyPath<Persistent, Element>, fileID: StaticString = #fileID, line: UInt = #line) -> IndexedBuffer<Element> {
        storage.persistentScope.indexedBuffer(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public func pool<Element: BitwiseCopyable>(_ keyPath: KeyPath<Persistent, Element>, fileID: StaticString = #fileID, line: UInt = #line) -> DensePool<Persistent, Element> {
        storage.persistentScope.densePool(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public func buffer(_ keyPath: KeyPath<Persistent, RawBytes>, fileID: StaticString = #fileID, line: UInt = #line) -> RawBuffer {
        storage.persistentScope.rawBuffer(keyPath, source: SourceLocation(fileID: fileID, line: line))
    }

    public func reportPeakUsage() { storage.log(ReportFormatter.peak(storage)) }
}

private func compileErased(_ type: any MemoryLayoutDefinition.Type) throws -> LayoutRecord {
    func open<Definition: MemoryLayoutDefinition>(_ type: Definition.Type) throws -> LayoutRecord {
        try LayoutCompiler.compile(type)
    }
    return try open(type)
}
