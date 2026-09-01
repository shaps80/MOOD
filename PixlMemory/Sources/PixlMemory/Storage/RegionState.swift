import Swift

final class RegionState: @unchecked Sendable {
    let record: RegionRecord
    var pointer: UnsafeMutableRawPointer?
    let placement: UInt64
    let borrow = BorrowState()
    weak var scope: ScopeStorage?

    var count: UInt64 = 0
    var peakCount: UInt64 = 0
    var reportedUsedBytes: UInt64 = 0
    var active = true
    var freeHead: UInt32 = .max
    var nextUnused: UInt32 = 0
    var capacity: UInt64
    var peakCapacity: UInt64
    private var ownsPointer = false

    init(record: RegionRecord, baseAddress: UnsafeMutableRawPointer?, placement: UInt64) {
        self.record = record
        if record.growth != nil {
            pointer = nil
            capacity = 0
            peakCapacity = 0
        } else {
            pointer = baseAddress?.advanced(by: Int(record.offset))
            capacity = record.capacity
            peakCapacity = record.capacity
        }
        self.placement = placement
    }

    deinit {
        if ownsPointer { pointer?.deallocate() }
    }

    var reservedBytes: UInt64 {
        if record.growth != nil {
            checkedMultiply(capacity, record.elementStride)
        } else {
            record.payload
        }
    }

    var peakReservedBytes: UInt64 {
        if record.growth != nil {
            checkedMultiply(peakCapacity, record.elementStride)
        } else {
            record.payload
        }
    }

    func grow(
        toFit required: UInt64,
        operation: String,
        access: SourceLocation
    ) -> Bool {
        guard let configuration = record.growth
        else { return false }
        let initialCapacity = configuration.initialCapacity
        let growth = configuration.growth
        var proposed = capacity == 0 ? initialCapacity : capacity
        while proposed < required {
            switch growth {
            case .doubling:
                proposed = checkedMultiply(proposed, 2)
            }
        }
        guard proposed > capacity else { return true }

        let oldReserved = reservedBytes
        let byteCount = checkedMultiply(proposed, record.elementStride)
        let replacement = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteCount),
            alignment: Int(record.alignment)
        )
        if let pointer, count > 0 {
            replacement.copyMemory(
                from: pointer,
                byteCount: Int(checkedMultiply(count, record.elementStride))
            )
        }
        if ownsPointer { pointer?.deallocate() }
        pointer = replacement
        ownsPointer = true
        let previousCapacity = capacity
        capacity = proposed
        peakCapacity = max(peakCapacity, proposed)
        scope?.noteReservationChanged(from: oldReserved, to: reservedBytes)
        if let scope {
            scope.arena?.log(ReportFormatter.growth(
                arenaName: scope.arena?.name,
                layout: scope.layout.name,
                region: record.name,
                operation: operation,
                previousCapacity: previousCapacity,
                capacity: proposed,
                required: required,
                previousReserved: oldReserved,
                reserved: reservedBytes,
                access: access
            ))
        }
        return true
    }

    var usedBytes: UInt64 {
        switch record.kind {
        case .indexed:
            checkedMultiply(count, record.elementStride)
        case .raw:
            count
        case .densePool:
            PoolLayout.calculate(
                capacity: count,
                elementStride: record.elementStride,
                elementAlignment: record.alignment
            ).required
        }
    }

    var peakBytes: UInt64 {
        switch record.kind {
        case .indexed:
            checkedMultiply(peakCount, record.elementStride)
        case .raw:
            peakCount
        case .densePool:
            PoolLayout.calculate(
                capacity: peakCount,
                elementStride: record.elementStride,
                elementAlignment: record.alignment
            ).required
        }
    }

    func reset() {
        let previousReserved = reservedBytes
        count = 0
        reportedUsedBytes = 0
        freeHead = .max
        nextUnused = 0
        if ownsPointer {
            pointer?.deallocate()
            pointer = nil
            ownsPointer = false
            capacity = 0
            scope?.noteReservationChanged(from: previousReserved, to: 0)
        }
        active = false
    }
}
