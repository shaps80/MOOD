import Swift

final class Metadata {
    private static let free: UInt32 = 1 << 31
    private static let value: UInt32 = free - 1
    private static let end = value

    let capacity: Int

    private let locations: UnsafeMutableBufferPointer<UInt32>
    private let generations: UnsafeMutableBufferPointer<UInt16>
    private var firstFree = end

    init(capacity: Int, count: Int) {
        precondition(capacity >= 0 && capacity < Int(Self.end))
        precondition(count >= 0 && count <= capacity)

        self.capacity = capacity
        locations = .allocate(capacity: capacity)
        generations = .allocate(capacity: capacity)
        locations.initialize(repeating: 0)
        generations.initialize(repeating: 0)
        initialize(count: count)
    }

    deinit {
        locations.deinitialize()
        locations.deallocate()
        generations.deinitialize()
        generations.deallocate()
    }

    var byteCount: Int {
        capacity * (
            MemoryLayout<UInt32>.stride + MemoryLayout<UInt16>.stride
        )
    }

    func reset(count: Int) {
        precondition(count >= 0 && count <= capacity)
        generations.update(repeating: 0)
        initialize(count: count)
    }

    @inline(__always)
    func resolve(_ id: Particle.ID) -> (slot: UInt32, index: Int)? {
        guard id >> 48 == 0 else { return nil }

        let slot = UInt32(truncatingIfNeeded: id)
        guard slot < capacity else { return nil }

        let location = locations[Int(slot)]
        guard location & Self.free == 0 else { return nil }
        guard generations[Int(slot)] == UInt16(truncatingIfNeeded: id >> 32)
        else { return nil }

        return (slot, Int(location))
    }

    @inline(__always)
    func id(for slot: UInt32) -> Particle.ID {
        precondition(slot < capacity)
        return Particle.ID(generations[Int(slot)]) << 32 | Particle.ID(slot)
    }

    @inline(__always)
    func move(_ slot: UInt32, to index: Int) {
        precondition(slot < capacity)
        precondition(index >= 0 && index < Int(Self.end))
        precondition(locations[Int(slot)] & Self.free == 0)
        locations[Int(slot)] = UInt32(index)
    }

    @inline(__always)
    func indexForKnownLiveSlot(_ slot: UInt32) -> Int {
        Int(locations[Int(slot)])
    }

    @inline(__always)
    func release(_ slot: UInt32) {
        precondition(slot < capacity)
        precondition(locations[Int(slot)] & Self.free == 0)

        let index = Int(slot)
        generations[index] &+= 1
        locations[index] = Self.free | firstFree
        firstFree = slot
    }

    @inline(__always)
    func recycle(_ slot: UInt32, at index: Int) -> Particle.ID {
        precondition(slot < capacity)
        precondition(index >= 0 && index < Int(Self.end))
        precondition(locations[Int(slot)] & Self.free == 0)

        let slotIndex = Int(slot)
        generations[slotIndex] &+= 1
        locations[slotIndex] = UInt32(index)
        return id(for: slot)
    }

    @inline(__always)
    func allocate(at index: Int) -> (slot: UInt32, id: Particle.ID)? {
        guard firstFree != Self.end else { return nil }
        return allocateAvailable(at: index)
    }

    @inline(__always)
    func allocateAvailable(at index: Int) -> (slot: UInt32, id: Particle.ID) {
        precondition(index >= 0 && index < Int(Self.end))

        let slot = firstFree
        let location = locations[Int(slot)]
        precondition(location & Self.free != 0)
        firstFree = location & Self.value
        locations[Int(slot)] = UInt32(index)
        return (slot, id(for: slot))
    }

    private func initialize(count: Int) {
        firstFree = count == capacity ? Self.end : UInt32(count)

        for index in 0..<capacity {
            let location: UInt32
            if index < count {
                location = UInt32(index)
            } else {
                let next = index + 1 < capacity ? UInt32(index + 1) : Self.end
                location = Self.free | next
            }

            locations[index] = location
        }
    }
}
