import PixlMemory
import Testing

@Layout("Aligned persistent", policy: .eager)
private struct AlignedPersistent {
    @Region var flag: UInt8

    static func make(_ layout: inout Layout) {
        layout.reserve(\.flag, count: 1)
    }
}

@Layout("Aligned level", policy: .eager)
private struct AlignedLevel {
    @Region var vector: SIMD4<Float>

    static func make(_ layout: inout Layout) {
        layout.reserve(\.vector, count: 1)
    }
}

@Test
private func arenaAccountsForAlignmentAndLiveUsage() throws {
    let arena = try Arena(
        AlignedPersistent.self,
        layouts: AlignedLevel.self,
        logging: .disabled
    )

    #expect(arena.reserved == .bytes(32))
    #expect(arena.statistics.used == .bytes(0))

    arena.buffer(\.flag).append(1)
    #expect(arena.statistics.used == .bytes(1))

    let level = arena.acquire(AlignedLevel.self)
    level.buffer(\.vector).append(.zero)
    #expect(arena.statistics.used == .bytes(17))
    #expect(arena.statistics.peak == .bytes(17))

    level.release()
    #expect(arena.statistics.used == .bytes(1))
    #expect(arena.statistics.peak == .bytes(17))
}

@Test
private func releasedTopLevelStorageCanBeReacquiredEmpty() throws {
    let arena = try Arena(
        AlignedPersistent.self,
        layouts: AlignedLevel.self,
        logging: .disabled
    )

    let first = arena.acquire(AlignedLevel.self)
    first.buffer(\.vector).append(.zero)
    first.release()

    let second = arena.acquire(AlignedLevel.self)
    let vector = second.buffer(\.vector)
    #expect(vector.capacity == 1)
    #expect(vector.count == 0)
    vector.append(SIMD4(repeating: 2))
    #expect(vector.count == 1)
    second.release()
}

@Layout("Nested child")
private struct NestedChild {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 2)
    }
}

@Layout("Nested parent")
private struct NestedParent {
    @Region var values: UInt16

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 2)
        layout.reserve(NestedChild.self)
    }
}

@Test
private func nestedLayoutsReleaseIndependentlyAndWithTheirParent() throws {
    let arena = try Arena(
        AlignedPersistent.self,
        layouts: NestedParent.self,
        logging: .disabled
    )
    let parent = arena.acquire(NestedParent.self)
    parent.buffer(\.values).append(1)

    let firstChild = parent.acquire(NestedChild.self)
    firstChild.buffer(\.values).append(1)
    #expect(parent.statistics.used == .bytes(6))
    firstChild.release()
    #expect(parent.statistics.used == .bytes(2))

    let secondChild = parent.acquire(NestedChild.self)
    #expect(secondChild.buffer(\.values).count == 0)
    secondChild.buffer(\.values).append(2)
    #expect(parent.statistics.used == .bytes(6))

    parent.release()
    #expect(arena.statistics.used == .bytes(0))

    let reacquired = arena.acquire(NestedParent.self)
    #expect(reacquired.buffer(\.values).count == 0)
    let reacquiredChild = reacquired.acquire(NestedChild.self)
    #expect(reacquiredChild.buffer(\.values).count == 0)
    reacquired.release()
}

@Layout("Empty persistent")
private struct EmptyPersistent {}

@Test
private func emptyArenaReservesNoMemory() throws {
    let arena = try Arena(EmptyPersistent.self, logging: .disabled)
    #expect(arena.reserved == .bytes(0))
    #expect(arena.statistics.reserved == .bytes(0))
    #expect(arena.statistics.used == .bytes(0))
    #expect(arena.statistics.peak == .bytes(0))
}

@Test
private func duplicateTopLevelLayoutsAreRejected() {
    #expect(throws: MemoryFailure.self) {
        try Arena(
            EmptyPersistent.self,
            layouts: AlignedLevel.self, AlignedLevel.self,
            logging: .disabled
        )
    }
}

@Layout("Recursive")
private struct RecursiveLayout {
    static func make(_ layout: inout Layout) {
        layout.reserve(RecursiveLayout.self)
    }
}

@Test
private func recursiveNestedLayoutsAreRejected() {
    #expect(throws: MemoryFailure.self) {
        try Arena(
            EmptyPersistent.self,
            layouts: RecursiveLayout.self,
            logging: .disabled
        )
    }
}
