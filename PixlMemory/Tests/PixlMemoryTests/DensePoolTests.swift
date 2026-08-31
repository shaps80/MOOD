import PixlMemory
import Testing

@Layout("Pool persistent")
struct PoolPersistent {
    static func make(_ layout: inout Layout) {}
}

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

@Layout("Pool isolation")
private struct PoolIsolationLayout {
    @Region(.densePool) var left: UInt32
    @Region(.densePool) var right: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.left, count: 2)
        layout.reserve(\.right, count: 2)
    }
}

@Test
private func handlesCannotCrossBetweenRegionsOfTheSameType() throws {
    let arena = try Arena(
        PoolPersistent.self,
        layouts: PoolIsolationLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(PoolIsolationLayout.self)
    let left = scope.pool(\.left)
    let right = scope.pool(\.right)
    let leftHandle = left.insert(10)
    let rightHandle = right.insert(20)

    #expect(left.contains(leftHandle))
    #expect(right.contains(rightHandle))
    #expect(!left.contains(rightHandle))
    #expect(!right.contains(leftHandle))
    scope.release()
}

private struct DeterministicGenerator {
    private var state: UInt64 = 0x4D59_5DF4_D0F3_3173

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}

@Layout("Randomised pool")
private struct RandomisedPoolLayout {
    @Region(.densePool) var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 64)
    }
}

@Test
private func densePoolMatchesAReferenceModelAcrossRandomOperations() throws {
    let arena = try Arena(
        PoolPersistent.self,
        layouts: RandomisedPoolLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(RandomisedPoolLayout.self)
    let pool = scope.pool(\.values)
    var generator = DeterministicGenerator()
    var entries: [(handle: DensePool<RandomisedPoolLayout, UInt32>.Handle, value: UInt32)] = []
    var nextValue: UInt32 = 1

    for operation in 0..<20_000 {
        let insert = entries.isEmpty
            || (entries.count < pool.capacity && generator.next() % 3 != 0)
        if insert {
            let value = nextValue
            nextValue &+= 1
            entries.append((pool.insert(value), value))
        } else {
            let index = Int(generator.next() % UInt64(entries.count))
            let entry = entries.remove(at: index)
            #expect(pool.remove(entry.handle) == entry.value)
            #expect(!pool.contains(entry.handle))
        }

        if operation.isMultiple(of: 31) {
            #expect(pool.count == entries.count)
            for entry in entries {
                #expect(pool.contains(entry.handle))
                #expect(pool.value(for: entry.handle) == entry.value)
            }
            #expect(Set(pool.withElements { Array($0) }) == Set(entries.map(\.value)))
        }
    }

    let oldHandles = entries.map(\.handle)
    pool.removeAll()
    #expect(pool.count == 0)
    for handle in oldHandles {
        #expect(!pool.contains(handle))
    }
    scope.release()
}
