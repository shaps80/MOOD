import Atomics
import PixlMemory
import Testing

private enum BorrowTestError: Error {
    case expected
}

@Test
private func readBorrowsCanOverlapAndAlwaysRelease() throws {
    let arena = try Arena(
        BufferPersistent.self,
        layouts: BufferLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(BufferLayout.self)
    let buffer = scope.buffer(\.integers)
    buffer.append(contentsOf: [1, 2, 3])

    let nestedTotal = buffer.withElements { outer in
        buffer.withElements { inner in
            outer.reduce(0, +) + inner.reduce(0, +)
        }
    }
    #expect(nestedTotal == 12)

    do {
        try buffer.withElements { _ in throw BorrowTestError.expected }
        Issue.record("Expected read closure to throw")
    } catch BorrowTestError.expected {}

    buffer.withMutableElements { elements in
        elements[0] = 10
    }
    #expect(buffer.withElements { Array($0) } == [10, 2, 3])
    scope.release()
}

@Test
private func separateThreadsCanReadTheSameRegionConcurrently() async throws {
    let arena = try Arena(
        BufferPersistent.self,
        layouts: BufferLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(BufferLayout.self)
    let buffer = scope.buffer(\.integers)
    buffer.append(contentsOf: [1, 2, 3])
    let entered = ManagedAtomic<Int>(0)

    func readConcurrently() -> Bool {
        buffer.withElements { elements in
            entered.wrappingIncrement(ordering: .acquiringAndReleasing)
            for _ in 0..<10_000_000 {
                if entered.load(ordering: .acquiring) == 2 {
                    return elements.reduce(0, +) == 6
                }
            }
            return false
        }
    }

    let first = Task.detached { readConcurrently() }
    let second = Task.detached { readConcurrently() }
    let results = await (first.value, second.value)
    #expect(results.0)
    #expect(results.1)

    buffer.withMutableElements { $0[0] = 10 }
    #expect(buffer.withElements { $0[0] } == 10)
    scope.release()
}
