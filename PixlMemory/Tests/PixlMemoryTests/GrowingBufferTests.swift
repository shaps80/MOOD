import PixlMemory
import Testing

@Layout("Chunked persistent")
private struct GrowingPersistent {
    @Region var submissions: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(
            \.submissions,
            initialCount: 2,
            growth: .doubling
        )
    }
}

@Layout("Growing level")
private struct GrowingLevel {
    @Region var submissions: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(
            \.submissions,
            initialCount: 2,
            growth: .doubling
        )
    }
}

@Layout("Growing parent")
private struct GrowingParent {
    static func make(_ layout: inout Layout) {
        layout.reserve(GrowingLevel.self)
    }
}

@Layout("Invalid growing buffer")
private struct InvalidGrowingBuffer {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, initialCount: 0, growth: .doubling)
    }
}

@Layout("Aligned growing buffer")
private struct AlignedGrowingBuffer {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(
            \.values,
            initialCount: 2,
            growth: .doubling,
            alignment: .bytes(64)
        )
    }
}

@Test
private func growingBufferGrowsWithoutAnInitialAllocation() throws {
    let arena = try Arena(GrowingPersistent.self, logging: .disabled)
    let submissions = arena.buffer(\.submissions)

    #expect(arena.reserved == .bytes(0))
    #expect(submissions.capacity == 0)
    submissions.append(contentsOf: [0, 1, 2, 3, 4])

    #expect(submissions.count == 5)
    #expect(submissions.capacity == 8)
    #expect(submissions.withElements { Array($0) } == [0, 1, 2, 3, 4])
    #expect(arena.statistics.reserved == .bytes(32))
    #expect(arena.statistics.used == .bytes(20))
    #expect(arena.statistics.peak == .bytes(20))
}

@Test
private func growingBufferRetainsCapacityForReuse() throws {
    let arena = try Arena(GrowingPersistent.self, logging: .disabled)
    let submissions = arena.buffer(\.submissions)
    submissions.append(contentsOf: [0, 1, 2, 3, 4])
    let originalAddress = submissions.withElements { $0.baseAddress }

    submissions.removeAll()
    submissions.append(contentsOf: [5, 6, 7, 8, 9, 10, 11, 12])

    #expect(submissions.capacity == 8)
    #expect(submissions.withElements { $0.baseAddress } == originalAddress)
    #expect(arena.statistics.reserved == .bytes(32))
    #expect(arena.statistics.used == .bytes(32))
}

@Test
private func releasingScopeReturnsGrowingStorageToTheSystem() throws {
    let arena = try Arena(
        EmptyPersistent.self,
        layouts: GrowingLevel.self,
        logging: .disabled
    )
    let first = arena.acquire(GrowingLevel.self)
    first.buffer(\.submissions).append(count: 5) { UInt32($0) }
    #expect(arena.reserved == .bytes(32))

    first.release()

    #expect(arena.reserved == .bytes(0))
    let second = arena.acquire(GrowingLevel.self)
    #expect(second.buffer(\.submissions).capacity == 0)
    second.release()
}

@Test
private func releasingParentReturnsNestedGrowingStorageToTheSystem() throws {
    let arena = try Arena(
        EmptyPersistent.self,
        layouts: GrowingParent.self,
        logging: .disabled
    )
    let parent = arena.acquire(GrowingParent.self)
    let child = parent.acquire(GrowingLevel.self)
    child.buffer(\.submissions).append(count: 5) { UInt32($0) }
    #expect(arena.reserved == .bytes(32))

    parent.release()

    #expect(arena.reserved == .bytes(0))
    #expect(arena.statistics.used == .bytes(0))
    #expect(arena.statistics.peak == .bytes(20))
}

@Test
private func growingWhileReadBorrowedTerminatesInsteadOfRelocatingStorage() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(GrowingPersistent.self, logging: .disabled)
        let submissions = arena.buffer(\.submissions)
        submissions.append(contentsOf: [0, 1])
        submissions.withElements { _ in
            submissions.append(2)
        }
    }
}

@Test
private func growingBufferRequiresAPositiveInitialCount() async {
    await #expect(processExitsWith: .failure) {
        _ = try Arena(InvalidGrowingBuffer.self, logging: .disabled)
    }
}

@Test
private func growingBufferHonoursAlignmentWithoutEagerAllocation() throws {
    let arena = try Arena(AlignedGrowingBuffer.self, logging: .disabled)
    let values = arena.buffer(\.values)
    #expect(arena.reserved == .bytes(0))

    values.append(1)

    #expect(values.withElements { Int(bitPattern: $0.baseAddress!) }.isMultiple(of: 64))
    #expect(arena.reserved == .bytes(8))
}
