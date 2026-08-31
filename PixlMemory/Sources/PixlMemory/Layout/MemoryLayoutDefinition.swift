import Swift

public protocol MemoryLayoutDefinition {
    typealias Layout = MemoryLayoutBuilder<Self>

    static var memoryLayoutName: String { get }
    static var preparationPolicy: PreparationPolicy? { get }
    static var memoryRegionDeclarations: [MemoryRegionDeclaration<Self>] { get }
    static func make(_ layout: inout Layout)
}

public struct MemoryLayoutBuilder<Definition: MemoryLayoutDefinition> {
    var entries: [LayoutEntryDraft] = []

    public init() {}

    public mutating func reserve<Element: BitwiseCopyable>(
        _ keyPath: KeyPath<Definition, Element>,
        count: Int,
        alignment: ByteCount? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        let source = SourceLocation(fileID: fileID, line: line)
        guard count >= 0 else {
            preconditionFailure("Region count must be nonnegative at \(source)")
        }
        let region = declaration(for: keyPath, at: source)
        let stride = UInt64(Swift.MemoryLayout<Element>.stride)
        let natural = UInt64(max(1, Swift.MemoryLayout<Element>.alignment))
        let requested = alignment?.rawValue ?? natural
        preconditionValidAlignment(requested, at: source)
        let capacity = UInt64(count)
        switch region.kind {
        case .indexedBuffer:
            let payload = checkedMultiply(stride, capacity)
            entries.append(.region(RegionDraft(
                name: region.name,
                kind: .indexed,
                policy: region.policy,
                capacity: capacity,
                payload: payload,
                alignment: max(natural, requested),
                elementStride: stride,
                source: source
            )))
        case .densePool:
            let pool = PoolLayout.calculate(
                capacity: capacity,
                elementStride: stride,
                elementAlignment: max(natural, requested)
            )
            entries.append(.region(RegionDraft(
                name: region.name,
                kind: .densePool(pool),
                policy: region.policy,
                capacity: capacity,
                payload: pool.required,
                alignment: pool.alignment,
                elementStride: stride,
                source: source
            )))
        case .rawBuffer:
            preconditionFailure("Raw region '\(region.name)' must be reserved using bytes at \(source)")
        }
    }

    public mutating func reserve(
        _ keyPath: KeyPath<Definition, RawBytes>,
        bytes: ByteCount,
        alignment: ByteCount = .bytes(1),
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        let source = SourceLocation(fileID: fileID, line: line)
        let region = declaration(for: keyPath, at: source)
        precondition(region.kind == .rawBuffer, "Memory region storage kind mismatch for '\(region.name)' at \(source)")
        preconditionValidAlignment(alignment.rawValue, at: source)
        entries.append(.region(RegionDraft(
            name: region.name,
            kind: .raw,
            policy: region.policy,
            capacity: bytes.rawValue,
            payload: bytes.rawValue,
            alignment: alignment.rawValue,
            elementStride: 1,
            source: source
        )))
    }

    public mutating func reserve<Child: MemoryLayoutDefinition>(
        _ child: Child.Type,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        entries.append(.child(ChildLayoutDraft(
            typeID: ObjectIdentifier(child),
            name: child.memoryLayoutName,
            source: SourceLocation(fileID: fileID, line: line),
            build: { stack in try LayoutCompiler.compile(child, stack: stack) }
        )))
    }

    private func declaration<Element>(for keyPath: KeyPath<Definition, Element>, at source: SourceLocation) -> MemoryRegionDeclaration<Definition> {
        guard let declaration = Definition.memoryRegionDeclarations.first(where: { $0.keyPath == keyPath }) else {
            preconditionFailure("Unknown memory region at \(source)")
        }
        return declaration
    }
}

private func preconditionValidAlignment(
    _ alignment: UInt64,
    at source: SourceLocation
) {
    precondition(
        alignment > 0 && alignment & (alignment - 1) == 0,
        "Region alignment must be a positive power of two at \(source)"
    )
}

enum LayoutEntryDraft {
    case region(RegionDraft)
    case child(ChildLayoutDraft)
}

struct RegionDraft {
    enum Kind {
        case indexed
        case raw
        case densePool(PoolLayout)
    }

    let name: String
    let kind: Kind
    let policy: PreparationPolicy?
    let capacity: UInt64
    let payload: UInt64
    let alignment: UInt64
    let elementStride: UInt64
    let source: SourceLocation
}

struct ChildLayoutDraft {
    let typeID: ObjectIdentifier
    let name: String
    let source: SourceLocation
    let build: ([ObjectIdentifier]) throws -> LayoutRecord
}

struct PoolLayout: Sendable {
    let valuesOffset: UInt64
    let sparseOffset: UInt64
    let denseSlotsOffset: UInt64
    let required: UInt64
    let alignment: UInt64

    static func calculate(
        capacity: UInt64,
        elementStride: UInt64,
        elementAlignment: UInt64
    ) -> Self {
        let metadataAlignment = UInt64(Swift.MemoryLayout<PoolSlot>.alignment)
        let alignment = max(elementAlignment, metadataAlignment)
        var cursor = UInt64(0)
        let valuesOffset = aligned(cursor, to: elementAlignment)
        cursor = checkedAdd(valuesOffset, checkedMultiply(capacity, elementStride))
        let sparseOffset = aligned(cursor, to: metadataAlignment)
        cursor = checkedAdd(sparseOffset, checkedMultiply(
            capacity,
            UInt64(Swift.MemoryLayout<PoolSlot>.stride)
        ))
        let denseSlotsOffset = aligned(cursor, to: UInt64(Swift.MemoryLayout<UInt32>.alignment))
        cursor = checkedAdd(denseSlotsOffset, checkedMultiply(
            capacity,
            UInt64(Swift.MemoryLayout<UInt32>.stride)
        ))
        return Self(
            valuesOffset: valuesOffset,
            sparseOffset: sparseOffset,
            denseSlotsOffset: denseSlotsOffset,
            required: aligned(cursor, to: alignment),
            alignment: alignment
        )
    }
}

struct PoolSlot: Sendable {
    var denseIndex: UInt32 = .max
    var generation: UInt32 = 1
    var nextFree: UInt32 = .max
}

func aligned(_ value: UInt64, to alignment: UInt64) -> UInt64 {
    let mask = alignment - 1
    return checkedAdd(value, mask) & ~mask
}

func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    precondition(!overflow, "Memory layout size overflow")
    return result
}

func checkedMultiply(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    precondition(!overflow, "Memory layout size overflow")
    return result
}
