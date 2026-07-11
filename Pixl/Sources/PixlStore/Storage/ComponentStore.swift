public final class ComponentStore<Schema: ComponentSchema, Group: StorageGroup> {
    private struct Slot {
        var generation: Int = 0
        var row: Int?

        var isActive: Bool {
            row != nil
        }
    }

    public var columns: Schema.Columns

    private var slots: [Slot]
    private var freeSlots: [Int]
    private var freeSlotHead: Int
    private var rowToSlot: [Int]
    private var capacity: Int
    private var slotCount: Int
    private var rowCountStorage: Int
    private var activeCountStorage: Int
    private var growthCount: Int
    private var compactionCount: Int

    public init(capacity: Int = Group.initialCapacity) {
        let normalizedCapacity = max(capacity, 1)

        self.columns = Schema.Columns()
        self.slots = Array(repeating: Slot(), count: normalizedCapacity)
        self.freeSlots = []
        self.freeSlotHead = 0
        self.rowToSlot = Array(repeating: -1, count: normalizedCapacity)
        self.capacity = normalizedCapacity
        self.slotCount = 0
        self.rowCountStorage = 0
        self.activeCountStorage = 0
        self.growthCount = 0
        self.compactionCount = 0

        columns.initializeStorage(capacity: normalizedCapacity)
    }

    public var metrics: StorageMetrics {
        let active = activeCount
        let rows = rowCountStorage

        return StorageMetrics(
            activeCount: active,
            rowCount: rows,
            tombstoneCount: max(rows - active, 0),
            capacity: capacity,
            growthCount: growthCount,
            compactionCount: compactionCount
        )
    }

    public var activeCount: Int {
        activeCountStorage
    }

    public var rowCount: Int {
        rowCountStorage
    }

    public func appendSlot() -> (
        handle: ComponentHandle<Schema, Group>,
        row: Int
    ) {
        ensureCapacityForAppend()

        let slotIndex = allocateSlot()
        let row = rowCountStorage

        columns.resetRowToDefault(row)
        rowToSlot[row] = slotIndex
        slots[slotIndex].row = row
        rowCountStorage += 1
        activeCountStorage += 1

        let handle = ComponentHandle<Schema, Group>(
            index: slotIndex,
            generation: slots[slotIndex].generation
        )

        return (handle, row)
    }

    public func insert(
        _ initialize: (_ row: Int, _ columns: inout Schema.Columns) -> Void
    ) -> ComponentHandle<Schema, Group> {
        let (handle, row) = appendSlot()
        initialize(row, &columns)
        return handle
    }

    public func remove(_ handle: ComponentHandle<Schema, Group>) {
        guard let slotIndex = validSlotIndex(for: handle),
              let row = slots[slotIndex].row
        else {
            return
        }

        switch Group.orderPolicy {
        case .stable:
            removeStable(slotIndex: slotIndex)

        case .unstable:
            removeUnstable(slotIndex: slotIndex, row: row)
        }
    }

    public func row(for handle: ComponentHandle<Schema, Group>) -> Int? {
        guard let slotIndex = validSlotIndex(for: handle) else {
            return nil
        }

        return slots[slotIndex].row
    }

    public func contains(_ handle: ComponentHandle<Schema, Group>) -> Bool {
        row(for: handle) != nil
    }

    public func isActiveRow(_ row: Int) -> Bool {
        guard rowToSlot.indices.contains(row) else {
            return false
        }

        let slotIndex = rowToSlot[row]
        return slotIndex >= 0 && slotIndex < slotCount && slots[slotIndex].row == row
    }

    public func handle(atActiveRow row: Int) -> ComponentHandle<Schema, Group>? {
        guard row >= 0 && row < rowCountStorage else {
            return nil
        }

        let slotIndex = rowToSlot[row]

        guard slotIndex >= 0,
              slotIndex < slotCount,
              slots[slotIndex].row == row
        else {
            return nil
        }

        return ComponentHandle(
            index: slotIndex,
            generation: slots[slotIndex].generation
        )
    }

    public func withRow<Result>(
        for handle: ComponentHandle<Schema, Group>,
        _ body: (_ row: Int, _ columns: Schema.Columns) throws -> Result
    ) rethrows -> Result? {
        guard let row = row(for: handle) else {
            return nil
        }

        return try body(row, columns)
    }

    public func withMutableRow<Result>(
        for handle: ComponentHandle<Schema, Group>,
        _ body: (_ row: Int, _ columns: inout Schema.Columns) throws -> Result
    ) rethrows -> Result? {
        guard let row = row(for: handle) else {
            return nil
        }

        return try body(row, &columns)
    }

    public func forEachActive(
        _ body: (_ handle: ComponentHandle<Schema, Group>, _ row: Int, _ columns: inout Schema.Columns) -> Void
    ) {
        for row in 0..<rowCountStorage {
            let slotIndex = rowToSlot[row]

            guard slotIndex >= 0,
                  slotIndex < slotCount,
                  slots[slotIndex].row == row
            else {
                continue
            }

            body(
                ComponentHandle(
                    index: slotIndex,
                    generation: slots[slotIndex].generation
                ),
                row,
                &columns
            )
        }
    }

    public func compactStableStorage() {
        guard Group.orderPolicy == .stable else {
            return
        }

        var destination = 0

        for source in 0..<rowCountStorage {
            let slotIndex = rowToSlot[source]

            guard slotIndex >= 0,
                  slotIndex < slotCount,
                  slots[slotIndex].row == source
            else {
                continue
            }

            if destination != source {
                columns.moveRow(from: source, to: destination)
            }

            rowToSlot[destination] = slotIndex
            slots[slotIndex].row = destination
            destination += 1
        }

        guard destination < rowCountStorage else {
            return
        }

        for row in destination..<rowCountStorage {
            rowToSlot[row] = -1
            columns.resetRowToDefault(row)
        }

        rowCountStorage = destination
        compactionCount += 1
    }

    public func removeAll(keepingCapacity keepCapacity: Bool = true) {
        if keepCapacity {
            for index in 0..<slotCount {
                slots[index] = Slot()
            }
            for row in 0..<rowCountStorage {
                rowToSlot[row] = -1
                columns.resetRowToDefault(row)
            }
        } else {
            capacity = max(Group.initialCapacity, 1)
            slots = Array(repeating: Slot(), count: capacity)
            rowToSlot = Array(repeating: -1, count: capacity)
            columns.initializeStorage(capacity: capacity)
        }

        freeSlots.removeAll(keepingCapacity: keepCapacity)
        freeSlotHead = 0
        slotCount = 0
        rowCountStorage = 0
        activeCountStorage = 0
    }

    private func removeStable(slotIndex: Int) {
        slots[slotIndex].row = nil
        slots[slotIndex].generation += 1
        freeSlots.append(slotIndex)
        activeCountStorage -= 1
    }

    private func removeUnstable(slotIndex: Int, row: Int) {
        let lastRow = rowCountStorage - 1

        if row != lastRow {
            let movedSlotIndex = rowToSlot[lastRow]

            columns.swapRows(row, lastRow)
            rowToSlot[row] = movedSlotIndex
            slots[movedSlotIndex].row = row
        }

        columns.resetRowToDefault(lastRow)
        rowToSlot[lastRow] = -1
        rowCountStorage -= 1

        slots[slotIndex].row = nil
        slots[slotIndex].generation += 1
        freeSlots.append(slotIndex)
        activeCountStorage -= 1
    }

    private func allocateSlot() -> Int {
        if freeSlotHead < freeSlots.count {
            let slotIndex = freeSlots[freeSlotHead]
            freeSlotHead += 1

            if freeSlotHead > 64 && freeSlotHead * 2 > freeSlots.count {
                freeSlots.removeFirst(freeSlotHead)
                freeSlotHead = 0
            }

            return slotIndex
        }

        if slotCount >= capacity {
            growStorage()
        }

        let slotIndex = slotCount
        slotCount += 1
        return slotIndex
    }

    private func validSlotIndex(
        for handle: ComponentHandle<Schema, Group>
    ) -> Int? {
        guard handle.index >= 0,
              handle.index < slotCount,
              slots[handle.index].generation == handle.generation,
              slots[handle.index].isActive
        else {
            return nil
        }

        return handle.index
    }

    private func ensureCapacityForAppend() {
        guard rowCountStorage >= capacity else {
            return
        }

        growStorage()
    }

    private func growStorage() {
        let oldCapacity = capacity
        capacity *= 2
        growthCount += 1
        slots.append(contentsOf: repeatElement(Slot(), count: capacity - oldCapacity))
        rowToSlot.append(contentsOf: repeatElement(-1, count: capacity - oldCapacity))
        columns.growStorage(from: oldCapacity, to: capacity)

        if Group.emitsGrowthWarnings {
            print(
                "PixlStore: grew \(Schema.name)/\(Group.name) storage from \(oldCapacity) to \(capacity)."
            )
        }
    }
}
