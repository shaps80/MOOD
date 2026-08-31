import PixlMemory
import Testing

@Layout("Pool persistent")
struct PoolPersistent {}

@Layout("Pool layout")
struct PoolLayoutFixture {
    @Region(.densePool) var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 4)
    }
}

@Test
private func densePoolPreservesLiveHandlesAndInvalidatesReusedHandles() throws {
    let arena = try Arena(
        PoolPersistent.self,
        layouts: PoolLayoutFixture.self,
        logging: .disabled
    )
    let scope = arena.acquire(PoolLayoutFixture.self)
    let pool = scope.pool(\.values)
    let first = pool.insert(10)
    let second = pool.insert(20)
    let third = pool.insert(30)

    #expect(pool.contains(first))
    #expect(pool.contains(second))
    #expect(pool.contains(third))
    #expect(pool.remove(second) == 20)
    #expect(!pool.contains(second))
    #expect(pool.value(for: first) == 10)
    #expect(pool.value(for: third) == 30)

    let replacement = pool.insert(40)
    #expect(!pool.contains(second))
    #expect(pool.contains(replacement))
    pool.withMutableValue(for: replacement) { $0 = 50 }
    #expect(pool.value(for: replacement) == 50)
    #expect(Set(pool.withElements { Array($0) }) == [10, 30, 50])

    pool.removeAll()
    #expect(!pool.contains(first))
    #expect(!pool.contains(third))
    #expect(!pool.contains(replacement))

    let afterReset = pool.insert(60)
    #expect(!pool.contains(first))
    #expect(!pool.contains(third))
    #expect(!pool.contains(replacement))
    #expect(pool.contains(afterReset))
    #expect(pool.value(for: afterReset) == 60)
    scope.release()
}

@Test
private func densePoolInvalidatesHandlesAcrossScopePlacements() throws {
    let arena = try Arena(
        PoolPersistent.self,
        layouts: PoolLayoutFixture.self,
        logging: .disabled
    )
    let firstScope = arena.acquire(PoolLayoutFixture.self)
    let firstPool = firstScope.pool(\.values)
    let oldHandle = firstPool.insert(10)
    firstScope.release()

    let secondScope = arena.acquire(PoolLayoutFixture.self)
    let secondPool = secondScope.pool(\.values)
    let newHandle = secondPool.insert(20)
    #expect(!secondPool.contains(oldHandle))
    #expect(secondPool.contains(newHandle))

    secondPool.withMutableElements { elements in
        elements[0] += 1
    }
    #expect(secondPool.value(for: newHandle) == 21)
    secondScope.release()
}
