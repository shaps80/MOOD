import Swift

/// FIFO runs preserve birth order without links or death ticks per particle.
/// Normal rate-based spawning needs roughly one run per live birth tick.
/// Explicit removals can split runs; fragmented workloads use more records.
final class BirthCohorts {
    private var records: UnsafeMutableBufferPointer<BirthCohort>
    private var head = 0
    private var count = 0

    init(capacity: Int, lifetimeTicks: UInt32) {
        // One extra run lets the current birth cohort follow expired particles
        // that are still being recycled. Explicit fragmentation grows on demand.
        let initial = max(1, min(capacity, Int(lifetimeTicks)) + 1)
        records = .allocate(capacity: initial)
        records.initialize(repeating: .init(lower: 0, upper: 0, deathTick: 0))
    }

    deinit {
        records.deinitialize()
        records.deallocate()
    }

    var byteCount: Int { records.count * MemoryLayout<BirthCohort>.stride }

    func reset() { head = 0; count = 0 }

    @inline(__always)
    private func physical(_ index: Int) -> Int { (head + index) % records.count }

    @inline(__always)
    func schedule(_ slot: UInt32, deathTick: UInt32) {
        if count > 0 {
            let tail = physical(count - 1)
            if records[tail].deathTick == deathTick && records[tail].upper == slot {
                records[tail].upper = slot + 1
                return
            }
        }
        ensureCapacity(count + 1)
        records[physical(count)] = .init(lower: slot, upper: slot + 1, deathTick: deathTick)
        count += 1
    }

    /// Explicit removal is uncommon; scan runs and split the containing range.
    /// Eager removal prevents a reused slot from inheriting its former expiry.
    func remove(_ slot: UInt32) {
        for index in 0..<count {
            let position = physical(index)
            let run = records[position]
            guard slot >= run.lower && slot < run.upper else { continue }
            if run.upper - run.lower == 1 {
                for next in index..<(count - 1) { records[physical(next)] = records[physical(next + 1)] }
                count -= 1
            } else if slot == run.lower {
                records[position].lower += 1
            } else if slot + 1 == run.upper {
                records[position].upper -= 1
            } else {
                ensureCapacity(count + 1)
                for next in stride(from: count, through: index + 2, by: -1) {
                    records[physical(next)] = records[physical(next - 1)]
                }
                records[physical(index)].upper = slot
                records[physical(index + 1)] = .init(lower: slot + 1, upper: run.upper, deathTick: run.deathTick)
                count += 1
            }
            return
        }
        preconditionFailure("Removing an unscheduled particle")
    }

    @inline(__always)
    func popExpired(at tick: UInt32) -> UInt32? {
        guard count > 0, records[head].deathTick == tick else { return nil }
        let slot = records[head].lower
        records[head].lower += 1
        if records[head].lower == records[head].upper {
            head = (head + 1) % records.count
            count -= 1
        }
        return slot
    }

    private func ensureCapacity(_ required: Int) {
        guard required > records.count else { return }
        let replacement = UnsafeMutableBufferPointer<BirthCohort>.allocate(capacity: max(required, records.count * 2))
        replacement.initialize(repeating: .init(lower: 0, upper: 0, deathTick: 0))
        for index in 0..<count { replacement[index] = records[physical(index)] }
        records.deinitialize()
        records.deallocate()
        records = replacement
        head = 0
    }
}
