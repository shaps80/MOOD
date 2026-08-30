import Testing
@testable import Pixl2D

@Suite
struct CollisionStoreTests {
    @Test
    func removedColliderIDCannotAccessReusedStorage() {
        let store = CollisionStore2D()
        let original = store.insert(
            Rect(x: 0, y: 0, width: 10, height: 10),
            isDynamic: true
        )

        store.remove(original)
        let replacementBounds = Rect(x: 20, y: 20, width: 5, height: 5)
        let replacement = store.insert(replacementBounds, isDynamic: false)

        #expect(original != replacement)
        #expect(store.bounds(for: original) == nil)
        #expect(store.bounds(for: replacement) == replacementBounds)
        #expect(store.count == 1)
    }

    @Test
    func movementReusesBroadBoundsUntilExactBoundsEscape() {
        let store = CollisionStore2D(broadMargin: 2)
        let id = store.insert(
            Rect(x: 0, y: 0, width: 10, height: 10),
            isDynamic: true
        )
        let initialBroadBounds = store.broadBounds(for: id)

        #expect(
            store.update(
                id,
                bounds: Rect(x: 1, y: 1, width: 10, height: 10)
            )
        )
        #expect(store.broadBounds(for: id) == initialBroadBounds)

        let escaped = Rect(x: 20, y: 20, width: 10, height: 10)
        #expect(store.update(id, bounds: escaped))
        #expect(store.bounds(for: id) == escaped)
        #expect(store.broadBounds(for: id) == escaped.padding(-2))
    }

    @Test
    func contactsUseExactBoundsAndSkipStaticPairs() {
        let store = CollisionStore2D(broadMargin: 10)
        let dynamic = store.insert(
            Rect(x: 0, y: 0, width: 10, height: 10),
            isDynamic: true
        )
        let touchingStatic = store.insert(
            Rect(x: 8, y: 0, width: 10, height: 10),
            isDynamic: false
        )
        _ = store.insert(
            Rect(x: 15, y: 0, width: 2, height: 2),
            isDynamic: false
        )
        let isolatedStatic = store.insert(
            Rect(x: 100, y: 100, width: 10, height: 10),
            isDynamic: false
        )
        _ = store.insert(
            Rect(x: 105, y: 100, width: 10, height: 10),
            isDynamic: false
        )
        var found: ColliderID?
        var contact: Contact2D?

        let dynamicContactCount = store.contacts(for: dynamic) { other, value in
            found = other
            contact = value
            return true
        }
        let staticContactCount = store.contacts(for: isolatedStatic) { _, _ in
            Issue.record("static-static contact should be skipped")
            return true
        }

        #expect(dynamicContactCount == 1)
        #expect(found == touchingStatic)
        #expect(contact?.depth == 2)
        #expect(staticContactCount == 0)
    }

    @Test
    func growthPreservesCollidersAndRemovedIDsStayInvalid() {
        let store = CollisionStore2D()
        let firstBounds = Rect(x: 1, y: 2, width: 3, height: 4)
        let first = store.insert(firstBounds, isDynamic: true)

        for index in 0..<128 {
            _ = store.insert(
                Rect(x: Float(index * 10), y: 20, width: 5, height: 5),
                isDynamic: index.isMultiple(of: 2)
            )
        }

        #expect(store.count == 129)
        #expect(store.bounds(for: first) == firstBounds)
        store.remove(first)
        #expect(store.bounds(for: first) == nil)
        #expect(store.count == 128)
    }

    @Test
    func rayUsesBroadPhaseButReturnsNearestExactHit() {
        let store = CollisionStore2D(broadMargin: 20)
        _ = store.insert(
            Rect(x: 10, y: 10, width: 5, height: 5),
            isDynamic: false
        )
        let farther = store.insert(
            Rect(x: 30, y: -5, width: 5, height: 10),
            isDynamic: false
        )
        let nearest = store.insert(
            Rect(x: 10, y: -5, width: 5, height: 10),
            isDynamic: true
        )
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        let hit = store.nearestRayHit(ray)

        #expect(hit?.collider == nearest)
        #expect(hit?.collider != farther)
        #expect(hit?.hit.distance == 10)
    }
}
