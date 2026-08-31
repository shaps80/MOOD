import Swift

final class RegionState: @unchecked Sendable {
    let record: RegionRecord
    let pointer: UnsafeMutableRawPointer?
    let placement: UInt64
    let borrow = BorrowState()
    weak var scope: ScopeStorage?

    var count: UInt64 = 0
    var peakCount: UInt64 = 0
    var reportedUsedBytes: UInt64 = 0
    var active = true
    var freeHead: UInt32 = .max
    var nextUnused: UInt32 = 0

    init(record: RegionRecord, baseAddress: UnsafeMutableRawPointer?, placement: UInt64) {
        self.record = record
        pointer = baseAddress?.advanced(by: Int(record.offset))
        self.placement = placement
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
        count = 0
        reportedUsedBytes = 0
        freeHead = .max
        nextUnused = 0
        active = false
    }
}
