import Swift

public struct RawBuffer: @unchecked Sendable {
    private let state: RegionState
    private let arena: ArenaStorage

    init(state: RegionState, arena: ArenaStorage) {
        self.state = state
        self.arena = arena
    }

    public var capacity: ByteCount { ByteCount(rawValue: state.record.capacity) }
    public var count: ByteCount { ByteCount(rawValue: state.count) }

    public func append<C: Collection>(contentsOf bytes: C, fileID: StaticString = #fileID, line: UInt = #line) where C.Element == UInt8 {
        append(bytes: ByteCount(rawValue: UInt64(bytes.count)), fileID: fileID, line: line) { destination in
            var index = 0
            for byte in bytes { destination[index] = byte; index += 1 }
        }
    }

    public func append(bytes: ByteCount, fileID: StaticString = #fileID, line: UInt = #line, _ fill: (UnsafeMutableRawBufferPointer) -> Void) {
        withWrite(fileID: fileID, line: line) {
            let required = checkedAdd(state.count, bytes.rawValue)
            guard required <= state.record.capacity else { capacityFailure(required, fileID, line) }
            let destination = UnsafeMutableRawBufferPointer(start: state.pointer?.advanced(by: Int(state.count)), count: Int(bytes.rawValue))
            fill(destination)
            state.count = required
            didChangeUsage()
        }
    }

    public func replace(in range: Range<Int>, fileID: StaticString = #fileID, line: UInt = #line, _ fill: (UnsafeMutableRawBufferPointer) -> Void) {
        withWrite(fileID: fileID, line: line) {
            guard range.lowerBound >= 0 && range.upperBound <= Int(state.count) else {
                arena.fail(title: "Raw buffer replacement is out of bounds", details: [("Region", state.record.name), ("Range", "\(range)"), ("Count", "\(state.count)")])
            }
            fill(UnsafeMutableRawBufferPointer(start: state.pointer?.advanced(by: range.lowerBound), count: range.count))
        }
    }

    public func removeAll(fileID: StaticString = #fileID, line: UInt = #line) {
        withWrite(fileID: fileID, line: line) { state.count = 0; didChangeUsage() }
    }

    public func withBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        requireActive(fileID, line)
        guard state.borrow.acquireRead() else { borrowFailure("read", fileID, line) }
        defer { state.borrow.releaseRead() }
        return try body(UnsafeRawBufferPointer(start: state.pointer, count: Int(state.count)))
    }

    public func withMutableBytes<Result>(_ body: (UnsafeMutableRawBufferPointer) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        requireActive(fileID, line)
        guard state.borrow.acquireWrite() else { borrowFailure("write", fileID, line) }
        defer { state.borrow.releaseWrite() }
        return try body(UnsafeMutableRawBufferPointer(start: state.pointer, count: Int(state.count)))
    }

    private func withWrite(fileID: StaticString, line: UInt, _ body: () -> Void) {
        requireActive(fileID, line)
        guard state.borrow.acquireWrite() else { borrowFailure("write", fileID, line) }
        defer { state.borrow.releaseWrite() }
        body()
    }

    private func requireActive(_ fileID: StaticString, _ line: UInt) {
        guard state.active else { arena.fail(title: "Region belongs to a released scope", details: [("Region", state.record.name), ("Location", SourceLocation(fileID: fileID, line: line).description)]) }
    }

    private func capacityFailure(_ required: UInt64, _ fileID: StaticString, _ line: UInt) -> Never {
        arena.fail(title: "Raw buffer capacity exceeded", details: [("Region", state.record.name), ("Capacity", "\(state.record.capacity) bytes"), ("Used", "\(state.count) bytes"), ("Required", "\(required) bytes"), ("Reservation", state.record.source.description), ("Location", SourceLocation(fileID: fileID, line: line).description), ("Fix", "layout.reserve(\\.\(state.record.name), bytes: .bytes(\(required)))")])
    }

    private func borrowFailure(_ operation: String, _ fileID: StaticString, _ line: UInt) -> Never {
        arena.fail(title: "Conflicting region access", details: [("Region", state.record.name), ("Requested", operation), ("Location", SourceLocation(fileID: fileID, line: line).description)])
    }

    private func didChangeUsage() {
        state.peakCount = max(state.peakCount, state.count)
        state.scope?.noteUsageChanged()
    }
}
