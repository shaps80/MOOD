import Swift

public struct IndexedBuffer<Element: BitwiseCopyable>: @unchecked Sendable {
    private let state: RegionState
    private let arena: ArenaStorage

    init(state: RegionState, arena: ArenaStorage) {
        self.state = state
        self.arena = arena
    }

    public var capacity: Int { Int(state.capacity) }
    public var count: Int { Int(state.count) }

    public func append(_ value: Element, fileID: StaticString = #fileID, line: UInt = #line) {
        withWrite(fileID: fileID, line: line) {
            requireCapacity(1, operation: "append", fileID: fileID, line: line)
            typedPointer.advanced(by: Int(state.count)).initialize(to: value)
            state.count += 1
            didChangeUsage()
        }
    }

    public func append<C: Collection>(contentsOf values: C, fileID: StaticString = #fileID, line: UInt = #line) where C.Element == Element {
        withWrite(fileID: fileID, line: line) {
            requireCapacity(UInt64(values.count), operation: "append(contentsOf:)", fileID: fileID, line: line)
            var destination = typedPointer.advanced(by: Int(state.count))
            for value in values {
                destination.initialize(to: value)
                destination = destination.advanced(by: 1)
            }
            state.count += UInt64(values.count)
            didChangeUsage()
        }
    }

    public func append(count: Int, _ make: (Int) -> Element, fileID: StaticString = #fileID, line: UInt = #line) {
        precondition(count >= 0, "Append count must be nonnegative")
        withWrite(fileID: fileID, line: line) {
            requireCapacity(UInt64(count), operation: "append(count:)", fileID: fileID, line: line)
            let start = Int(state.count)
            for offset in 0..<count {
                typedPointer.advanced(by: start + offset).initialize(to: make(start + offset))
            }
            state.count += UInt64(count)
            didChangeUsage()
        }
    }

    public func replace(in range: Range<Int>, _ make: (Int) -> Element, fileID: StaticString = #fileID, line: UInt = #line) {
        withWrite(fileID: fileID, line: line) {
            guard range.lowerBound >= 0 && range.upperBound <= Int(state.count) else {
                arena.fail(title: "Indexed buffer replacement is out of bounds", details: [
                    ("Region", state.record.name),
                    ("Range", "\(range)"),
                    ("Count", "\(state.count)"),
                    ("Location", SourceLocation(fileID: fileID, line: line).description)
                ])
            }
            for index in range { typedPointer.advanced(by: index).pointee = make(index) }
        }
    }

    public func removeAll(fileID: StaticString = #fileID, line: UInt = #line) {
        withWrite(fileID: fileID, line: line) {
            state.count = 0
            didChangeUsage()
        }
    }

    public func withElements<Result>(_ body: (Elements<Element>) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        requireActive(fileID: fileID, line: line)
        guard state.borrow.acquireRead() else { borrowFailure("read", fileID, line) }
        defer { state.borrow.releaseRead() }
        return try body(Elements(baseAddress: UnsafePointer(typedPointer), count: Int(state.count)))
    }

    public func withMutableElements<Result>(_ body: (MutableElements<Element>) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        requireActive(fileID: fileID, line: line)
        guard state.borrow.acquireWrite() else { borrowFailure("write", fileID, line) }
        defer { state.borrow.releaseWrite() }
        return try body(MutableElements(baseAddress: typedPointer, count: Int(state.count)))
    }

    private var typedPointer: UnsafeMutablePointer<Element> {
        state.pointer!.assumingMemoryBound(to: Element.self)
    }

    private func withWrite(fileID: StaticString, line: UInt, _ body: () -> Void) {
        requireActive(fileID: fileID, line: line)
        guard state.borrow.acquireWrite() else { borrowFailure("write", fileID, line) }
        defer { state.borrow.releaseWrite() }
        body()
    }

    private func requireCapacity(_ additional: UInt64, operation: String, fileID: StaticString, line: UInt) {
        let required = checkedAdd(state.count, additional)
        guard required > state.capacity else { return }
        let access = SourceLocation(fileID: fileID, line: line)
        guard state.grow(
            toFit: required,
            operation: operation,
            access: access
        ) else {
            arena.fail(.indexedBuffer(
                region: state.record.name,
                operation: operation,
                capacity: state.record.capacity,
                used: state.count,
                required: required,
                elementStride: state.record.elementStride,
                reservation: state.record.source,
                access: access
            ))
        }
    }

    private func requireActive(fileID: StaticString, line: UInt) {
        guard state.active else {
            arena.fail(title: "Region belongs to a released scope", details: [
                ("Region", state.record.name),
                ("Placement", "\(state.placement)"),
                ("Location", SourceLocation(fileID: fileID, line: line).description)
            ])
        }
    }

    private func borrowFailure(_ operation: String, _ fileID: StaticString, _ line: UInt) -> Never {
        arena.fail(title: "Conflicting region access", details: [
            ("Region", state.record.name),
            ("Requested", operation),
            ("Location", SourceLocation(fileID: fileID, line: line).description)
        ])
    }

    private func didChangeUsage() {
        state.peakCount = max(state.peakCount, state.count)
        let used = state.usedBytes
        state.scope?.noteUsageChanged(from: state.reportedUsedBytes, to: used)
        state.reportedUsedBytes = used
    }
}
