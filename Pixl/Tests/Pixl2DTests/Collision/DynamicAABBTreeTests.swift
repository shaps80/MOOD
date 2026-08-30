import Testing
@testable import Pixl2D

@Suite
struct DynamicAABBTreeTests {
    @Test
    func insertsProxy() {
        let tree = DynamicAABBTree2D()
        let bounds = Rect(x: 10, y: 20, width: 30, height: 40)

        let proxy = tree.insert(bounds)

        #expect(tree.count == 1)
        #expect(tree.bounds(for: proxy) == bounds)
    }

    @Test
    func growthPreservesLiveProxies() {
        let tree = DynamicAABBTree2D()
        let firstBounds = Rect(x: 1, y: 2, width: 3, height: 4)
        let first = tree.insert(firstBounds)

        for index in 0..<64 {
            _ = tree.insert(
                Rect(
                    x: Float(index),
                    y: Float(index),
                    width: 10,
                    height: 10
                )
            )
        }

        #expect(tree.count == 65)
        #expect(tree.bounds(for: first) == firstBounds)
        #expect(tree.validateStructure())
    }

    @Test
    func removedProxyCannotAccessReusedSlot() {
        let tree = DynamicAABBTree2D()
        let removed = tree.insert(
            Rect(x: 1, y: 2, width: 3, height: 4)
        )

        tree.remove(removed)
        let replacementBounds = Rect(x: 10, y: 20, width: 30, height: 40)
        let replacement = tree.insert(replacementBounds)
        tree.remove(removed)

        #expect(removed != replacement)
        #expect(tree.bounds(for: removed) == nil)
        #expect(tree.bounds(for: replacement) == replacementBounds)
        #expect(tree.count == 1)
        #expect(tree.validateStructure())
    }

    @Test
    func rayReturnsNearestProxyAndHit() {
        let tree = DynamicAABBTree2D()
        _ = tree.insert(Rect(x: 30, y: -5, width: 10, height: 10))
        let nearest = tree.insert(
            Rect(x: 10, y: -5, width: 10, height: 10)
        )
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        let result = Self.nearestHit(in: tree, ray: ray) { proxy in
            tree.bounds(for: proxy)
        }

        #expect(result?.proxy == nearest)
        #expect(result?.hit.distance == 10)
        #expect(result?.hit.normal == Vec2(-1, 0))
    }

    @Test
    func removingNearestProxyRevealsNextHit() {
        let tree = DynamicAABBTree2D()
        let nearest = tree.insert(
            Rect(x: 10, y: -5, width: 10, height: 10)
        )
        let farther = tree.insert(
            Rect(x: 30, y: -5, width: 10, height: 10)
        )
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        tree.remove(nearest)

        let result = Self.nearestHit(in: tree, ray: ray) { proxy in
            tree.bounds(for: proxy)
        }
        #expect(result?.proxy == farther)
        #expect(result?.hit.distance == 30)
    }

    @Test
    func removingFinalProxyEmptiesTree() {
        let tree = DynamicAABBTree2D()
        let proxy = tree.insert(
            Rect(x: 10, y: -5, width: 10, height: 10)
        )

        tree.remove(proxy)

        #expect(tree.count == 0)
        #expect(tree.height == 0)
        #expect(
            Self.nearestHit(
                in: tree,
                ray: Ray2D(origin: .zero, direction: .init(1, 0))
            ) { proxy in tree.bounds(for: proxy) } == nil
        )
    }

    @Test
    func rayMissingTreeReturnsNil() {
        let tree = DynamicAABBTree2D()
        _ = tree.insert(Rect(x: 10, y: 10, width: 10, height: 10))

        let result = Self.nearestHit(
            in: tree,
            ray: Ray2D(origin: .zero, direction: .init(1, 0))
        ) { proxy in tree.bounds(for: proxy) }

        #expect(result == nil)
    }

    @Test
    func orderedInsertionsRemainBalancedAndQueryable() {
        let tree = DynamicAABBTree2D()
        let first = tree.insert(
            Rect(x: 0, y: -1, width: 1, height: 2)
        )

        for index in 1..<256 {
            _ = tree.insert(
                Rect(
                    x: Float(index * 3),
                    y: -1,
                    width: 1,
                    height: 2
                )
            )
        }

        let result = Self.nearestHit(
            in: tree,
            ray: Ray2D(origin: .init(-10, 0), direction: .init(1, 0))
        ) { proxy in tree.bounds(for: proxy) }

        #expect(tree.count == 256)
        #expect(tree.height < 32)
        #expect(result?.proxy == first)
        #expect(result?.hit.distance == 10)
        #expect(tree.validateStructure())
    }

    @Test
    func equalDistanceHitsAreDeterministic() {
        let tree = DynamicAABBTree2D()
        _ = tree.insert(Rect(x: 10, y: -5, width: 10, height: 10))
        _ = tree.insert(Rect(x: 10, y: -5, width: 10, height: 10))
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        let first = Self.nearestHit(in: tree, ray: ray) { proxy in
            tree.bounds(for: proxy)
        }

        for _ in 0..<32 {
            let result = Self.nearestHit(in: tree, ray: ray) { proxy in
                tree.bounds(for: proxy)
            }
            #expect(result?.proxy == first?.proxy)
            #expect(result?.hit == first?.hit)
        }
        #expect(first?.hit.distance == 10)
        #expect(tree.validateStructure())
    }

    @Test
    func zeroSizeBoundsAndInsideOriginsRemainQueryable() {
        let pointTree = DynamicAABBTree2D()
        let point = pointTree.insert(
            Rect(x: 10, y: 0, width: 0, height: 0)
        )
        let containingTree = DynamicAABBTree2D()
        let containing = containingTree.insert(
            Rect(x: -5, y: -5, width: 10, height: 10)
        )

        #expect(
            Self.nearestHit(
                in: pointTree,
                ray: Ray2D(origin: .zero, direction: .init(1, 0))
            ) { proxy in pointTree.bounds(for: proxy) }?.proxy == point
        )
        #expect(
            Self.nearestHit(
                in: containingTree,
                ray: Ray2D(origin: .zero, direction: .init(1, 0))
            ) { proxy in containingTree.bounds(for: proxy) }?.proxy == containing
        )
        #expect(
            Self.nearestHit(
                in: containingTree,
                ray: Ray2D(origin: .zero, direction: .init(1, 0))
            ) { proxy in containingTree.bounds(for: proxy) }?.hit.distance == 5
        )
    }

    @Test
    func overlapQueryVisitsOnlyOverlappingProxies() {
        let tree = DynamicAABBTree2D()
        let touching = tree.insert(Rect(x: 10, y: 0, width: 10, height: 10))
        let overlapping = tree.insert(Rect(x: 5, y: 5, width: 2, height: 2))
        let outside = tree.insert(Rect(x: 30, y: 30, width: 5, height: 5))
        var sawTouching = false
        var sawOverlapping = false
        var sawOutside = false

        let stats = tree.query(
            overlapping: Rect(x: 0, y: 0, width: 10, height: 10)
        ) { proxy, _ in
            sawTouching = sawTouching || proxy == touching
            sawOverlapping = sawOverlapping || proxy == overlapping
            sawOutside = sawOutside || proxy == outside
            return true
        }

        #expect(sawTouching)
        #expect(sawOverlapping)
        #expect(!sawOutside)
        #expect(stats.leafVisits == 2)
    }

    @Test
    func proxyPreservesOpaqueColliderIndex() {
        let tree = DynamicAABBTree2D()
        _ = tree.insert(
            Rect(x: 0, y: 0, width: 10, height: 10),
            userData: 42
        )
        var received: Int32?

        tree.query(
            overlapping: Rect(x: 0, y: 0, width: 10, height: 10)
        ) { _, userData in
            received = userData
            return true
        }

        #expect(received == 42)
    }

    @Test
    func overlapQueryCanTerminateWithoutVisitingEveryLeaf() {
        let tree = DynamicAABBTree2D()
        for index in 0..<32 {
            _ = tree.insert(Rect(x: Float(index), y: 0, width: 1, height: 1))
        }

        var callbackCount = 0
        let stats = tree.query(
            overlapping: Rect(x: -1, y: -1, width: 100, height: 100)
        ) { _, _ in
            callbackCount += 1
            return false
        }

        #expect(callbackCount == 1)
        #expect(stats.leafVisits == 1)
        #expect(stats.nodeVisits < (tree.count * 2 - 1))
    }

    @Test
    func movingProxyUpdatesItsBroadPhaseBounds() {
        let tree = DynamicAABBTree2D()
        let original = Rect(x: 0, y: 0, width: 10, height: 10)
        let moved = Rect(x: 100, y: 100, width: 10, height: 10)
        let proxy = tree.insert(original)

        #expect(tree.move(proxy, to: moved))
        #expect(tree.bounds(for: proxy) == moved)
        #expect(!Self.query(tree, original, finds: proxy))
        #expect(Self.query(tree, moved, finds: proxy))
        #expect(tree.validateStructure())

        tree.remove(proxy)
        #expect(!tree.move(proxy, to: original))
    }

    @Test
    func enlargingProxyPreservesExistingBoundsAndUpdatesAncestors() {
        let tree = DynamicAABBTree2D()
        let original = Rect(x: 10, y: 10, width: 10, height: 10)
        let proxy = tree.insert(original)
        _ = tree.insert(Rect(x: 100, y: 100, width: 10, height: 10))

        #expect(
            tree.enlarge(
                proxy,
                toInclude: Rect(x: 0, y: 0, width: 5, height: 5)
            )
        )
        #expect(
            tree.bounds(for: proxy)
                == Rect(x: 0, y: 0, width: 20, height: 20)
        )
        #expect(
            Self.query(
                tree,
                Rect(x: 1, y: 1, width: 1, height: 1),
                finds: proxy
            )
        )
        #expect(tree.validateStructure())
        #expect(!tree.enlarge(proxy, toInclude: original))
    }

    @Test
    func rayCastLeavesExactShapeTestingToCaller() {
        let tree = DynamicAABBTree2D()
        let broadBounds = Rect(x: 10, y: -10, width: 20, height: 20)
        let exactBounds = Rect(x: 15, y: 5, width: 5, height: 5)
        let proxy = tree.insert(broadBounds)
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))
        var candidateCount = 0

        let result = Self.nearestHit(in: tree, ray: ray) { candidate in
            candidateCount += 1
            return candidate == proxy ? exactBounds : nil
        }

        #expect(candidateCount == 1)
        #expect(result == nil)
    }

    @Test
    func randomizedMutationsAndRaysMatchBruteForce() {
        let capacity = 512
        let records = UnsafeMutablePointer<Record>.allocate(capacity: capacity)
        var initializedCount = 0
        defer {
            records.deinitialize(count: initializedCount)
            records.deallocate()
        }

        var random = Generator(seed: 0xC0FFEE)
        let tree = DynamicAABBTree2D()

        for index in 0..<384 {
            let bounds = Self.randomBounds(using: &random)
            let proxy = tree.insert(bounds)
            records.advanced(by: index).initialize(
                to: .init(proxy: proxy, bounds: bounds, isLive: true)
            )
            initializedCount += 1
        }
        #expect(tree.validateStructure())

        Self.assertRandomRaysMatchOracle(
            tree: tree,
            records: records,
            count: initializedCount,
            random: &random,
            rayCount: 1_000
        )
        Self.assertRandomQueriesMatchOracle(
            tree: tree,
            records: records,
            count: initializedCount,
            random: &random,
            queryCount: 500
        )

        for index in 0..<initializedCount where index.isMultiple(of: 3) {
            tree.remove(records[index].proxy)
            records[index].isLive = false
            if index.isMultiple(of: 24) {
                #expect(tree.validateStructure())
            }
        }

        for index in initializedCount..<capacity {
            let bounds = Self.randomBounds(using: &random)
            let proxy = tree.insert(bounds)
            records.advanced(by: index).initialize(
                to: .init(proxy: proxy, bounds: bounds, isLive: true)
            )
            initializedCount += 1
        }
        #expect(tree.validateStructure())

        Self.assertRandomRaysMatchOracle(
            tree: tree,
            records: records,
            count: initializedCount,
            random: &random,
            rayCount: 1_000
        )
        Self.assertRandomQueriesMatchOracle(
            tree: tree,
            records: records,
            count: initializedCount,
            random: &random,
            queryCount: 500
        )

        for index in stride(from: initializedCount - 1, through: 0, by: -1) {
            guard records[index].isLive else { continue }
            tree.remove(records[index].proxy)
            records[index].isLive = false
            if index.isMultiple(of: 31) {
                #expect(tree.validateStructure())
            }
        }

        #expect(tree.count == 0)
        #expect(tree.validateStructure())
    }

    @Test
    func interleavedRandomMutationsPreserveQueriesAndStructure() {
        let capacity = 128
        let records = UnsafeMutablePointer<Record>.allocate(capacity: capacity)
        defer {
            records.deinitialize(count: capacity)
            records.deallocate()
        }

        var random = Generator(seed: 0xBADC0DE)
        let tree = DynamicAABBTree2D()

        for index in 0..<capacity {
            let bounds = Self.randomBounds(using: &random)
            records.advanced(by: index).initialize(
                to: .init(
                    proxy: tree.insert(bounds),
                    bounds: bounds,
                    isLive: true
                )
            )
        }

        for operation in 0..<4_000 {
            let index = random.int(upperBound: capacity)
            if records[index].isLive {
                tree.remove(records[index].proxy)
                records[index].isLive = false
            } else {
                let bounds = Self.randomBounds(using: &random)
                records[index] = .init(
                    proxy: tree.insert(bounds),
                    bounds: bounds,
                    isLive: true
                )
            }

            if operation.isMultiple(of: 40) {
                #expect(tree.validateStructure())
                Self.assertRandomRaysMatchOracle(
                    tree: tree,
                    records: records,
                    count: capacity,
                    random: &random,
                    rayCount: 20
                )
                Self.assertRandomQueriesMatchOracle(
                    tree: tree,
                    records: records,
                    count: capacity,
                    random: &random,
                    queryCount: 10
                )
            }
        }

        #expect(tree.validateStructure())
    }
}

private extension DynamicAABBTreeTests {
    struct TreeHit {
        let proxy: ProxyID
        let hit: RayHit2D
    }

    struct Record {
        let proxy: ProxyID
        let bounds: Rect
        var isLive: Bool
    }

    struct Generator {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func float(in range: ClosedRange<Float>) -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let value = Float(UInt32(truncatingIfNeeded: state >> 32))
                / Float(UInt32.max)
            return range.lowerBound
                + ((range.upperBound - range.lowerBound) * value)
        }

        mutating func int(upperBound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return Int(state % UInt64(upperBound))
        }
    }

    static func randomBounds(using random: inout Generator) -> Rect {
        Rect(
            x: random.float(in: -1_000...1_000),
            y: random.float(in: -1_000...1_000),
            width: random.float(in: 0...40),
            height: random.float(in: 0...40)
        )
    }

    static func nearestHit(
        in tree: DynamicAABBTree2D,
        ray: Ray2D,
        exactBounds: (ProxyID) -> Rect?
    ) -> TreeHit? {
        var result: TreeHit?
        tree.rayCast(ray) { proxy, _, maximumDistance in
            guard let bounds = exactBounds(proxy),
                  let hit = bounds.intersection(with: ray),
                  hit.distance < maximumDistance
            else { return .ignore }

            result = .init(proxy: proxy, hit: hit)
            return .clip(to: hit.distance)
        }
        return result
    }

    static func query(
        _ tree: DynamicAABBTree2D,
        _ bounds: Rect,
        finds expected: ProxyID
    ) -> Bool {
        var found = false
        tree.query(overlapping: bounds) { proxy, _ in
            found = found || proxy == expected
            return true
        }
        return found
    }

    static func assertRandomRaysMatchOracle(
        tree: DynamicAABBTree2D,
        records: UnsafeMutablePointer<Record>,
        count: Int,
        random: inout Generator,
        rayCount: Int
    ) {
        for _ in 0..<rayCount {
            var direction = Vec2(
                random.float(in: -1...1),
                random.float(in: -1...1)
            )
            if direction == .zero {
                direction = .init(1, 0)
            }
            let ray = Ray2D(
                origin: .init(
                    random.float(in: -1_200...1_200),
                    random.float(in: -1_200...1_200)
                ),
                direction: direction
            )

            var expectedDistance = Float.infinity
            for index in 0..<count where records[index].isLive {
                if let hit = records[index].bounds.intersection(with: ray) {
                    expectedDistance = min(expectedDistance, hit.distance)
                }
            }

            let result = Self.nearestHit(in: tree, ray: ray) { proxy in
                for index in 0..<count
                where records[index].isLive && records[index].proxy == proxy {
                    return records[index].bounds
                }
                return nil
            }
            if expectedDistance == .infinity {
                #expect(result == nil)
                continue
            }

            #expect(result != nil)
            #expect(
                abs((result?.hit.distance ?? .infinity) - expectedDistance)
                    < 0.000_1
            )

            var matchedLiveProxy = false
            if let result {
                for index in 0..<count
                where records[index].isLive
                    && records[index].proxy == result.proxy
                {
                    matchedLiveProxy = true
                    #expect(
                        abs(
                            (records[index].bounds.intersection(with: ray)?.distance
                                ?? .infinity) - expectedDistance
                        ) < 0.000_1
                    )
                    break
                }
            }
            #expect(matchedLiveProxy)
        }
    }

    static func assertRandomQueriesMatchOracle(
        tree: DynamicAABBTree2D,
        records: UnsafeMutablePointer<Record>,
        count: Int,
        random: inout Generator,
        queryCount: Int
    ) {
        let seen = UnsafeMutablePointer<Bool>.allocate(capacity: count)
        defer { seen.deallocate() }

        for _ in 0..<queryCount {
            seen.initialize(repeating: false, count: count)
            defer { seen.deinitialize(count: count) }
            let queryBounds = Self.randomBounds(using: &random)

            tree.query(overlapping: queryBounds) { proxy, _ in
                var matchedIndex: Int?
                for index in 0..<count
                where records[index].isLive && records[index].proxy == proxy {
                    matchedIndex = index
                    break
                }

                #expect(matchedIndex != nil)
                if let index = matchedIndex {
                    #expect(!seen[index])
                    #expect(Self.overlaps(records[index].bounds, queryBounds))
                    seen[index] = true
                }
                return true
            }

            for index in 0..<count where records[index].isLive {
                #expect(
                    seen[index]
                        == Self.overlaps(records[index].bounds, queryBounds)
                )
            }
        }
    }

    static func overlaps(_ lhs: Rect, _ rhs: Rect) -> Bool {
        lhs.minX <= rhs.maxX
            && lhs.maxX >= rhs.minX
            && lhs.minY <= rhs.maxY
            && lhs.maxY >= rhs.minY
    }
}
