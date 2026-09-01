import Swift

final class LayoutRecord: @unchecked Sendable {
    let typeID: ObjectIdentifier
    let name: String
    let policy: PreparationPolicy?
    let entries: [LayoutEntryRecord]
    let payload: UInt64
    let required: UInt64
    let alignment: UInt64

    init(typeID: ObjectIdentifier, name: String, policy: PreparationPolicy?, entries: [LayoutEntryRecord], payload: UInt64, required: UInt64, alignment: UInt64) {
        self.typeID = typeID
        self.name = name
        self.policy = policy
        self.entries = entries
        self.payload = payload
        self.required = required
        self.alignment = alignment
    }
}

enum LayoutEntryRecord: @unchecked Sendable {
    case region(RegionRecord)
    case child(ChildRecord)
}

struct RegionRecord: @unchecked Sendable {
    let name: String
    let kind: RegionDraft.Kind
    let growth: IndexedGrowth?
    let policy: PreparationPolicy?
    let capacity: UInt64
    let payload: UInt64
    let alignment: UInt64
    let elementStride: UInt64
    let offset: UInt64
    let source: SourceLocation
}

struct ChildRecord: @unchecked Sendable {
    let layout: LayoutRecord
    let offset: UInt64
    let source: SourceLocation
}

enum LayoutCompiler {
    static func compile<Definition: MemoryLayoutDefinition>(_ type: Definition.Type, stack: [ObjectIdentifier] = []) throws -> LayoutRecord {
        let typeID = ObjectIdentifier(type)
        guard !stack.contains(typeID) else {
            throw MemoryFailure("Recursive nested memory layout '\(Definition.memoryLayoutName)'")
        }
        var builder = MemoryLayoutBuilder<Definition>()
        Definition.make(&builder)
        var names = Set<String>()
        var cursor = UInt64(0)
        var payload = UInt64(0)
        var maximumAlignment = UInt64(1)
        var records: [LayoutEntryRecord] = []

        for entry in builder.entries {
            switch entry {
            case .region(let draft):
                guard names.insert(draft.name).inserted else {
                    throw MemoryFailure("Duplicate region '\(draft.name)' in layout '\(Definition.memoryLayoutName)'")
                }
                cursor = aligned(cursor, to: draft.alignment)
                records.append(.region(RegionRecord(name: draft.name, kind: draft.kind, growth: draft.growth, policy: draft.policy, capacity: draft.capacity, payload: draft.payload, alignment: draft.alignment, elementStride: draft.elementStride, offset: cursor, source: draft.source)))
                cursor = checkedAdd(cursor, draft.payload)
                payload = checkedAdd(payload, draft.payload)
                maximumAlignment = max(maximumAlignment, draft.alignment)
            case .child(let draft):
                let child = try draft.build(stack + [typeID])
                guard names.insert(child.name).inserted else {
                    throw MemoryFailure("Duplicate nested layout '\(child.name)' in layout '\(Definition.memoryLayoutName)'")
                }
                cursor = aligned(cursor, to: child.alignment)
                records.append(.child(ChildRecord(layout: child, offset: cursor, source: draft.source)))
                cursor = checkedAdd(cursor, child.required)
                payload = checkedAdd(payload, child.required)
                maximumAlignment = max(maximumAlignment, child.alignment)
            }
        }
        if cursor > 0 { cursor = aligned(cursor, to: maximumAlignment) }
        return LayoutRecord(typeID: typeID, name: Definition.memoryLayoutName, policy: Definition.preparationPolicy, entries: records, payload: payload, required: cursor, alignment: maximumAlignment)
    }
}
