import Testing
import Pixl2D

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
    }
}
