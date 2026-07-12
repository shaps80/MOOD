import Testing
@testable import PixlPlatform

@Suite("ResourcePool")
struct ResourcePoolTests {
    @Test
    func fixedCapacityLookupRemovalAndReuse() {
        let pool = ResourcePool<UInt64>(capacity: 2)
        let first = pool.insert(10)
        let second = pool.insert(20)

        #expect(first != nil)
        #expect(second != nil)
        #expect(pool.count == 2)
        #expect(pool.insert(30) == nil)

        var value: UInt64 = 0
        #expect(pool.withValue(for: first!) { value = $0.pointee } != nil)
        #expect(value == 10)
        #expect(pool.update(first!) { $0.pointee = 11 } != nil)
        #expect(pool.remove(first!))
        #expect(!pool.contains(first!))
        #expect(pool.withValue(for: first!) { _ in } == nil)

        let replacement = pool.insert(30)
        #expect(replacement != nil)
        #expect(replacement!.index == first!.index)
        #expect(replacement!.generation != first!.generation)
        #expect(pool.contains(second!))
    }
}
