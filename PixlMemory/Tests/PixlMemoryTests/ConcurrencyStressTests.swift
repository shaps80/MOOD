import PixlMemory
import Testing

@Layout("Concurrent regions")
private struct ConcurrentRegionsLayout {
    @Region var left: UInt32
    @Region var right: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.left, count: 5_000)
        layout.reserve(\.right, count: 5_000)
    }
}

@Test
private func separateRegionsCanBeWrittenFromSeparateThreads() async throws {
    let arena = try Arena(
        EmptyPersistent.self,
        layouts: ConcurrentRegionsLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(ConcurrentRegionsLayout.self)
    let left = scope.buffer(\.left)
    let right = scope.buffer(\.right)

    let leftWriter = Task.detached {
        for value in 0..<5_000 {
            left.append(UInt32(value))
        }
    }
    let rightWriter = Task.detached {
        for value in 0..<5_000 {
            right.append(UInt32(value))
        }
    }
    await leftWriter.value
    await rightWriter.value

    #expect(left.count == 5_000)
    #expect(right.count == 5_000)
    #expect(left.withElements { $0[4_999] } == 4_999)
    #expect(right.withElements { $0[4_999] } == 4_999)
    #expect(scope.statistics.used == .bytes(40_000))
    #expect(scope.statistics.peak == .bytes(40_000))
    scope.release()
}
