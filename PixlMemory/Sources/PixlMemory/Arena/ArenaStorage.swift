import Swift
import Atomics

final class ArenaStorage: @unchecked Sendable {
    let name: String?
    let logging: ArenaLogging
    let persistentRecord: LayoutRecord
    let layouts: [ObjectIdentifier: LayoutRecord]
    let reserved: UInt64
    let topLevelOffset: UInt64
    let pointer: UnsafeMutableRawPointer?
    let persistentScope: ScopeStorage
    let layoutOrder: [LayoutRecord]
    var history: [ScopeStorage] = []

    private var activeTopLevel: ScopeStorage?
    private var nextPlacement: UInt64 = 1
    private let used = ManagedAtomic<UInt64>(0)
    private let peakUsage = ManagedAtomic<UInt64>(0)

    init(name: String?, logging: ArenaLogging, persistent: LayoutRecord, layouts: [LayoutRecord]) {
        self.name = name
        self.logging = logging
        persistentRecord = persistent
        layoutOrder = layouts
        self.layouts = Dictionary(uniqueKeysWithValues: layouts.map { ($0.typeID, $0) })
        let topAlignment = layouts.map(\.alignment).max() ?? 1
        topLevelOffset = aligned(persistent.required, to: topAlignment)
        reserved = checkedAdd(topLevelOffset, layouts.map(\.required).max() ?? 0)
        let arenaAlignment = max(persistent.alignment, topAlignment)
        pointer = reserved == 0 ? nil : UnsafeMutableRawPointer.allocate(byteCount: Int(reserved), alignment: Int(arenaAlignment))
        persistentScope = ScopeStorage(arena: nil, layout: persistent, baseAddress: pointer, placement: 0, effectivePolicy: persistent.policy ?? .eager, parent: nil)
        persistentScope.arena = self
        history.append(persistentScope)
        persistentScope.prepareDirectRegions()
    }

    deinit {
        activeTopLevel?.release(cascading: true)
        persistentScope.release(cascading: true)
        pointer?.deallocate()
    }

    var statistics: MemoryStatistics {
        MemoryStatistics(
            reserved: ByteCount(rawValue: reserved),
            used: ByteCount(rawValue: currentUsed),
            peak: ByteCount(rawValue: peak)
        )
    }

    var currentUsed: UInt64 { used.load(ordering: .acquiring) }
    var peak: UInt64 { peakUsage.load(ordering: .acquiring) }

    func acquire<Definition: MemoryLayoutDefinition>(_ type: Definition.Type, policy: PreparationPolicy?, source: SourceLocation) -> ScopeStorage {
        guard activeTopLevel == nil else {
            fail(title: "Top-level layout already acquired", details: [("Active", activeTopLevel!.layout.name), ("Requested", Definition.memoryLayoutName), ("Location", source.description)])
        }
        guard let layout = layouts[ObjectIdentifier(type)] else {
            fail(title: "Layout is not registered", details: [("Layout", Definition.memoryLayoutName), ("Location", source.description)])
        }
        let scope = ScopeStorage(arena: self, layout: layout, baseAddress: pointer?.advanced(by: Int(topLevelOffset)), placement: takePlacement(), effectivePolicy: policy ?? layout.policy ?? .eager, parent: nil)
        activeTopLevel = scope
        history.append(scope)
        scope.prepareDirectRegions()
        log(ReportFormatter.acquired(scope))
        return scope
    }

    func scopeDidRelease(_ scope: ScopeStorage) {
        if activeTopLevel === scope { activeTopLevel = nil }
    }

    func noteUsageChanged(from previous: UInt64, to current: UInt64) {
        let updated: UInt64
        if current >= previous {
            let delta = current - previous
            let old = used.loadThenWrappingIncrement(
                by: delta,
                ordering: .acquiringAndReleasing
            )
            updated = old + delta
        } else {
            let delta = previous - current
            let old = used.loadThenWrappingDecrement(
                by: delta,
                ordering: .acquiringAndReleasing
            )
            precondition(old >= delta, "Arena usage underflow")
            updated = old - delta
        }
        updateMaximum(peakUsage, with: updated)
    }

    func takePlacement() -> UInt64 {
        defer { nextPlacement &+= 1 }
        return nextPlacement
    }

    func log(_ message: @autoclosure () -> String) {
        guard logging == .automatic else { return }
        print(message())
    }

    func fail(title: String, details: [(String, String)]) -> Never {
        log(ReportFormatter.failure(arenaName: name, title: title, details: details))
        fatalError("PixlMemory failure")
    }

    func fail(_ failure: CapacityFailure) -> Never {
        log(ReportFormatter.failure(arenaName: name, capacity: failure))
        fatalError("PixlMemory failure")
    }
}

func updateMaximum(_ atomic: ManagedAtomic<UInt64>, with candidate: UInt64) {
    var current = atomic.load(ordering: .acquiring)
    while candidate > current {
        let result = atomic.compareExchange(
            expected: current,
            desired: candidate,
            ordering: .acquiringAndReleasing
        )
        if result.exchanged { return }
        current = result.original
    }
}
