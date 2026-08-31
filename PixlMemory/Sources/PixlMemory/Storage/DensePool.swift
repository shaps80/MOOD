import Swift

public struct DensePoolHandle<Layout, Element: BitwiseCopyable>: Hashable, Sendable {
    fileprivate let placement: UInt64
    fileprivate let regionOffset: UInt64
    fileprivate let slot: UInt32
    fileprivate let generation: UInt32
}

public struct DensePool<Layout, Element: BitwiseCopyable>: @unchecked Sendable {
    public typealias Handle = DensePoolHandle<Layout, Element>

    private let state: RegionState
    private let arena: ArenaStorage

    init(state: RegionState, arena: ArenaStorage) {
        self.state = state
        self.arena = arena
    }

    public var capacity: Int { Int(state.record.capacity) }
    public var count: Int { Int(state.count) }

    public func insert(_ value: Element, fileID: StaticString = #fileID, line: UInt = #line) -> Handle {
        withWrite(fileID, line) {
            let required = checkedAdd(state.count, 1)
            guard required <= state.record.capacity else { capacityFailure(required, fileID, line) }
            let slotIndex: UInt32
            if state.freeHead != .max {
                slotIndex = state.freeHead
                state.freeHead = slots[Int(slotIndex)].nextFree
            } else {
                slotIndex = state.nextUnused
                state.nextUnused &+= 1
                slots.advanced(by: Int(slotIndex)).initialize(to: PoolSlot())
            }
            let denseIndex = UInt32(state.count)
            if state.count < state.peakCount {
                values[Int(denseIndex)] = value
                denseSlots[Int(denseIndex)] = slotIndex
            } else {
                values.advanced(by: Int(denseIndex)).initialize(to: value)
                denseSlots.advanced(by: Int(denseIndex)).initialize(to: slotIndex)
            }
            slots[Int(slotIndex)].denseIndex = denseIndex
            slots[Int(slotIndex)].nextFree = .max
            state.count = required
            didChangeUsage()
            return Handle(
                placement: state.placement,
                regionOffset: state.record.offset,
                slot: slotIndex,
                generation: slots[Int(slotIndex)].generation
            )
        }
    }

    public func contains(_ handle: Handle) -> Bool {
        guard state.active,
              state.borrow.acquireRead()
        else { return false }
        defer { state.borrow.releaseRead() }
        return validatedDenseIndex(handle) != nil
    }

    public func value(for handle: Handle, fileID: StaticString = #fileID, line: UInt = #line) -> Element {
        withRead(fileID, line) {
            values[Int(requireDenseIndex(handle, operation: "value(for:)", fileID, line))]
        }
    }

    public func withMutableValue<Result>(for handle: Handle, _ body: (inout Element) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        try withWrite(fileID, line) {
            let index = requireDenseIndex(handle, operation: "withMutableValue(for:)", fileID, line)
            return try body(&values[Int(index)])
        }
    }

    @discardableResult
    public func remove(_ handle: Handle, fileID: StaticString = #fileID, line: UInt = #line) -> Element {
        withWrite(fileID, line) {
            let denseIndex = requireDenseIndex(handle, operation: "remove", fileID, line)
            let lastIndex = UInt32(state.count - 1)
            let removed = values[Int(denseIndex)]
            if denseIndex != lastIndex {
                values[Int(denseIndex)] = values[Int(lastIndex)]
                let movedSlot = denseSlots[Int(lastIndex)]
                denseSlots[Int(denseIndex)] = movedSlot
                slots[Int(movedSlot)].denseIndex = denseIndex
            }
            var slot = slots[Int(handle.slot)]
            slot.denseIndex = .max
            slot.generation &+= 1
            if slot.generation == 0 { slot.generation = 1 }
            slot.nextFree = state.freeHead
            slots[Int(handle.slot)] = slot
            state.freeHead = handle.slot
            state.count -= 1
            didChangeUsage()
            return removed
        }
    }

    public func removeAll(fileID: StaticString = #fileID, line: UInt = #line) {
        withWrite(fileID, line) {
            for index in 0..<state.nextUnused {
                var slot = slots[Int(index)]
                slot.denseIndex = .max
                slot.generation &+= 1
                if slot.generation == 0 { slot.generation = 1 }
                slot.nextFree = index + 1 < state.nextUnused ? index + 1 : .max
                slots[Int(index)] = slot
            }
            state.count = 0
            state.freeHead = state.nextUnused == 0 ? .max : 0
            didChangeUsage()
        }
    }

    public func withElements<Result>(_ body: (Elements<Element>) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        try withRead(fileID, line) {
            try body(Elements(baseAddress: UnsafePointer(values), count: Int(state.count)))
        }
    }

    public func withMutableElements<Result>(_ body: (MutableElements<Element>) throws -> Result, fileID: StaticString = #fileID, line: UInt = #line) rethrows -> Result {
        try withWrite(fileID, line) {
            try body(MutableElements(baseAddress: values, count: Int(state.count)))
        }
    }

    private var poolLayout: PoolLayout {
        guard case .densePool(let layout) = state.record.kind else {
            fatalError("Invalid dense pool region")
        }
        return layout
    }

    private var values: UnsafeMutablePointer<Element> {
        state.pointer!.advanced(by: Int(poolLayout.valuesOffset)).assumingMemoryBound(to: Element.self)
    }

    private var slots: UnsafeMutablePointer<PoolSlot> {
        state.pointer!.advanced(by: Int(poolLayout.sparseOffset)).assumingMemoryBound(to: PoolSlot.self)
    }

    private var denseSlots: UnsafeMutablePointer<UInt32> {
        state.pointer!.advanced(by: Int(poolLayout.denseSlotsOffset)).assumingMemoryBound(to: UInt32.self)
    }

    private func validatedDenseIndex(_ handle: Handle) -> UInt32? {
        guard handle.placement == state.placement,
              handle.regionOffset == state.record.offset,
              handle.slot < state.nextUnused
        else { return nil }
        let slot = slots[Int(handle.slot)]
        guard slot.denseIndex != .max,
              slot.denseIndex < state.count,
              slot.generation == handle.generation
        else { return nil }
        return slot.denseIndex
    }

    private func requireDenseIndex(_ handle: Handle, operation: String, _ fileID: StaticString, _ line: UInt) -> UInt32 {
        guard let index = validatedDenseIndex(handle) else {
            let reason: String
            if handle.placement != state.placement {
                reason = "Handle belongs to a different pool placement."
            } else if handle.regionOffset != state.record.offset {
                reason = "Handle belongs to a different pool region."
            } else {
                reason = "Handle is stale or no longer live."
            }
            arena.fail(title: "Invalid dense-pool handle", details: [
                ("Operation", operation),
                ("Target", "\(state.record.name) [placement \(state.placement)]"),
                ("Handle origin", "\(state.record.name) [placement \(handle.placement)]"),
                ("Reason", reason),
                ("Fix", "Discard handles when their owning scope is released."),
                ("Location", SourceLocation(fileID: fileID, line: line).description)
            ])
        }
        return index
    }

    private func withRead<Result>(_ fileID: StaticString, _ line: UInt, _ body: () throws -> Result) rethrows -> Result {
        requireActive(fileID, line)
        guard state.borrow.acquireRead() else { borrowFailure("read", fileID, line) }
        defer { state.borrow.releaseRead() }
        return try body()
    }

    private func withWrite<Result>(_ fileID: StaticString, _ line: UInt, _ body: () throws -> Result) rethrows -> Result {
        requireActive(fileID, line)
        guard state.borrow.acquireWrite() else { borrowFailure("write", fileID, line) }
        defer { state.borrow.releaseWrite() }
        return try body()
    }

    private func requireActive(_ fileID: StaticString, _ line: UInt) {
        guard state.active else { arena.fail(title: "Region belongs to a released scope", details: [("Region", state.record.name), ("Placement", "\(state.placement)"), ("Location", SourceLocation(fileID: fileID, line: line).description)]) }
    }

    private func capacityFailure(_ required: UInt64, _ fileID: StaticString, _ line: UInt) -> Never {
        arena.fail(.densePool(
            region: state.record.name,
            operation: "insert",
            capacity: state.record.capacity,
            used: state.count,
            required: required,
            elementStride: state.record.elementStride,
            elementAlignment: state.record.alignment,
            reservation: state.record.source,
            access: SourceLocation(fileID: fileID, line: line)
        ))
    }

    private func borrowFailure(_ operation: String, _ fileID: StaticString, _ line: UInt) -> Never {
        arena.fail(title: "Conflicting region access", details: [("Region", state.record.name), ("Requested", operation), ("Location", SourceLocation(fileID: fileID, line: line).description)])
    }

    private func didChangeUsage() {
        state.peakCount = max(state.peakCount, state.count)
        let used = state.usedBytes
        state.scope?.noteUsageChanged(from: state.reportedUsedBytes, to: used)
        state.reportedUsedBytes = used
    }
}
