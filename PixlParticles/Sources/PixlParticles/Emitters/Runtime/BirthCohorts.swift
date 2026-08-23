import Swift

final class BirthCohorts {
    private static let invalidSlot = UInt32.max
    private static let unscheduledTick = UInt64.max

    private let capacity: Int
    private let deathTicks: UnsafeMutableBufferPointer<UInt64>
    private let next: UnsafeMutableBufferPointer<UInt32>
    private let previous: UnsafeMutableBufferPointer<UInt32>

    private var first = invalidSlot
    private var last = invalidSlot

    init(capacity: Int) {
        precondition(capacity >= 0 && capacity < Int(Self.invalidSlot))

        self.capacity = capacity
        deathTicks = .allocate(capacity: capacity)
        next = .allocate(capacity: capacity)
        previous = .allocate(capacity: capacity)
        deathTicks.initialize(repeating: Self.unscheduledTick)
        next.initialize(repeating: Self.invalidSlot)
        previous.initialize(repeating: Self.invalidSlot)
    }

    deinit {
        deathTicks.deinitialize()
        deathTicks.deallocate()
        next.deinitialize()
        next.deallocate()
        previous.deinitialize()
        previous.deallocate()
    }

    var byteCount: Int {
        capacity * (
            MemoryLayout<UInt64>.stride
                + MemoryLayout<UInt32>.stride
                + MemoryLayout<UInt32>.stride
        )
    }

    func reset() {
        deathTicks.update(repeating: Self.unscheduledTick)
        first = Self.invalidSlot
        last = Self.invalidSlot
    }

    @inline(__always)
    func schedule(_ slot: UInt32, deathTick: UInt64) {
        let index = Int(slot)
        deathTicks[index] = deathTick
        next[index] = Self.invalidSlot
        previous[index] = last

        if last == Self.invalidSlot {
            first = slot
        } else {
            next[Int(last)] = slot
        }
        last = slot
    }

    @inline(__always)
    func remove(_ slot: UInt32) {
        let index = Int(slot)
        let previousSlot = previous[index]
        let nextSlot = next[index]

        if previousSlot == Self.invalidSlot {
            first = nextSlot
        } else {
            next[Int(previousSlot)] = nextSlot
        }

        if nextSlot == Self.invalidSlot {
            last = previousSlot
        } else {
            previous[Int(nextSlot)] = previousSlot
        }

        deathTicks[index] = Self.unscheduledTick
    }

    @inline(__always)
    func popExpired(at tick: UInt64) -> UInt32? {
        let slot = first
        guard slot != Self.invalidSlot else { return nil }
        guard deathTicks[Int(slot)] == tick else { return nil }
        remove(slot)
        return slot
    }
}
