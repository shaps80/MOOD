import Swift

final class ScopeStorage: @unchecked Sendable {
    weak var arena: ArenaStorage?
    let layout: LayoutRecord
    let baseAddress: UnsafeMutableRawPointer?
    let placement: UInt64
    let effectivePolicy: PreparationPolicy
    weak var parent: ScopeStorage?
    let regions: [String: RegionState]

    private var children: [ObjectIdentifier: ScopeStorage] = [:]
    private(set) var active = true
    private(set) var peakUsed: UInt64 = 0

    init(arena: ArenaStorage?, layout: LayoutRecord, baseAddress: UnsafeMutableRawPointer?, placement: UInt64, effectivePolicy: PreparationPolicy, parent: ScopeStorage?) {
        self.arena = arena
        self.layout = layout
        self.baseAddress = baseAddress
        self.placement = placement
        self.effectivePolicy = effectivePolicy
        self.parent = parent
        var states: [String: RegionState] = [:]
        for case .region(let record) in layout.entries {
            states[record.name] = RegionState(
                record: record,
                baseAddress: baseAddress,
                placement: placement
            )
        }
        regions = states
        for state in states.values { state.scope = self }
    }

    var statistics: MemoryStatistics {
        MemoryStatistics(
            reserved: ByteCount(rawValue: layout.required),
            used: ByteCount(rawValue: currentUsed),
            peak: ByteCount(rawValue: peakUsed)
        )
    }

    var currentUsed: UInt64 {
        var total: UInt64 = 0
        for state in regions.values { total = checkedAdd(total, state.usedBytes) }
        for child in children.values where child.active {
            total = checkedAdd(total, child.currentUsed)
        }
        return total
    }

    func prepareDirectRegions() {
        for state in regions.values {
            let policy = state.record.policy ?? layout.policy ?? effectivePolicy
            guard policy == .eager, state.record.payload > 0 else { continue }
            state.pointer?.initializeMemory(
                as: UInt8.self,
                repeating: 0,
                count: Int(state.record.payload)
            )
        }
    }

    func acquire<Child: MemoryLayoutDefinition>(_ type: Child.Type, policy: PreparationPolicy?, source: SourceLocation) -> ScopeStorage {
        requireActive(source)
        let typeID = ObjectIdentifier(type)
        guard children[typeID] == nil else {
            arena!.fail(title: "Nested layout already acquired", details: [
                ("Parent", layout.name),
                ("Layout", Child.memoryLayoutName),
                ("Location", source.description)
            ])
        }
        guard let childRecord = layout.entries.compactMap({ entry -> ChildRecord? in
            if case .child(let child) = entry, child.layout.typeID == typeID { return child }
            return nil
        }).first else {
            arena!.fail(title: "Nested layout is not reserved", details: [
                ("Parent", layout.name),
                ("Layout", Child.memoryLayoutName),
                ("Location", source.description),
                ("Fix", "layout.reserve(\(Child.self))")
            ])
        }
        let child = ScopeStorage(
            arena: arena,
            layout: childRecord.layout,
            baseAddress: baseAddress?.advanced(by: Int(childRecord.offset)),
            placement: arena!.takePlacement(),
            effectivePolicy: policy ?? childRecord.layout.policy ?? effectivePolicy,
            parent: self
        )
        children[typeID] = child
        arena!.history.append(child)
        child.prepareDirectRegions()
        arena!.log(ReportFormatter.acquired(child))
        noteUsageChanged()
        return child
    }

    func release(cascading: Bool) {
        guard active else { return }
        for state in regions.values where state.borrow.isBorrowed {
            arena!.fail(title: "Cannot release borrowed scope", details: [
                ("Layout", layout.name),
                ("Region", state.record.name)
            ])
        }
        if cascading {
            for child in children.values { child.release(cascading: true) }
        }
        for state in regions.values { state.reset() }
        active = false
        children.removeAll(keepingCapacity: true)
        parent?.childDidRelease(self)
        arena?.scopeDidRelease(self)
    }

    func indexedBuffer<Definition: MemoryLayoutDefinition, Element: BitwiseCopyable>(_ keyPath: KeyPath<Definition, Element>, source: SourceLocation) -> IndexedBuffer<Element> {
        let declaration = requireDeclaration(keyPath, source: source)
        let state = requireRegion(declaration.name, source: source)
        guard case .indexed = state.record.kind else { kindFailure(declaration.name, source) }
        return IndexedBuffer(state: state, arena: arena!)
    }

    func rawBuffer<Definition: MemoryLayoutDefinition>(_ keyPath: KeyPath<Definition, RawBytes>, source: SourceLocation) -> RawBuffer {
        let declaration = requireDeclaration(keyPath, source: source)
        let state = requireRegion(declaration.name, source: source)
        guard case .raw = state.record.kind else { kindFailure(declaration.name, source) }
        return RawBuffer(state: state, arena: arena!)
    }

    func densePool<Definition: MemoryLayoutDefinition, Element: BitwiseCopyable>(_ keyPath: KeyPath<Definition, Element>, source: SourceLocation) -> DensePool<Definition, Element> {
        let declaration = requireDeclaration(keyPath, source: source)
        let state = requireRegion(declaration.name, source: source)
        guard case .densePool = state.record.kind else { kindFailure(declaration.name, source) }
        return DensePool(state: state, arena: arena!)
    }

    func noteUsageChanged() {
        peakUsed = max(peakUsed, currentUsed)
        parent?.noteUsageChanged()
        arena?.usageDidChange()
    }

    private func childDidRelease(_ child: ScopeStorage) {
        children.removeValue(forKey: child.layout.typeID)
        noteUsageChanged()
    }

    private func requireActive(_ source: SourceLocation) {
        guard active else {
            arena!.fail(title: "Scope has been released", details: [
                ("Layout", layout.name),
                ("Location", source.description)
            ])
        }
    }

    private func requireRegion(_ name: String, source: SourceLocation) -> RegionState {
        requireActive(source)
        guard let state = regions[name] else {
            arena!.fail(title: "Region is not reserved", details: [
                ("Layout", layout.name),
                ("Region", name),
                ("Location", source.description),
                ("Fix", "layout.reserve(\\.\(name), ...)")
            ])
        }
        return state
    }

    private func requireDeclaration<Definition: MemoryLayoutDefinition, Element>(
        _ keyPath: KeyPath<Definition, Element>,
        source: SourceLocation
    ) -> MemoryRegionDeclaration<Definition> {
        guard layout.typeID == ObjectIdentifier(Definition.self) else {
            arena!.fail(title: "Region belongs to a different layout", details: [
                ("Active", layout.name),
                ("Requested", Definition.memoryLayoutName),
                ("Location", source.description)
            ])
        }
        guard let declaration = Definition.memoryRegionDeclarations.first(where: { $0.keyPath == keyPath }) else {
            arena!.fail(title: "Unknown memory region", details: [
                ("Layout", layout.name),
                ("Location", source.description)
            ])
        }
        return declaration
    }

    private func kindFailure(_ name: String, _ source: SourceLocation) -> Never {
        arena!.fail(title: "Region storage kind mismatch", details: [
            ("Layout", layout.name),
            ("Region", name),
            ("Location", source.description)
        ])
    }
}
