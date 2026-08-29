import Pixl2D
import Testing

@Suite
struct CollisionTests {
    @Test
    func storesNormalAndDepth() {
        let contact = Contact2D(
            normal: .init(1, 0),
            depth: 2
        )

        #expect(contact.normal == .init(1, 0))
        #expect(contact.depth == 2)
    }

    @Test
    func separatedRectanglesHaveNoContact() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 20, y: 0, width: 10, height: 10)

        #expect(first.contact(with: second) == nil)
    }

    @Test
    func overlappingRectanglesHaveContact() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 8, y: 0, width: 10, height: 10)

        #expect(first.contact(with: second) != nil)
    }

    @Test
    func touchingRectanglesHaveNoContact() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 10, y: 0, width: 10, height: 10)

        #expect(first.contact(with: second) == nil)
    }

    @Test
    func containedRectangleUsesDistanceToNearestExit() {
        let inner = Rect(x: 2, y: 4, width: 2, height: 2)
        let outer = Rect(x: 0, y: 0, width: 10, height: 10)

        let contact = inner.contact(with: outer)

        #expect(contact?.normal == .init(1, 0))
        #expect(contact?.depth == 4)
    }

    @Test
    func identicalRectanglesChoosePositiveHorizontalNormal() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 0, y: 0, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.normal == .init(1, 0))
        #expect(contact?.depth == 10)
    }

    @Test
    func invalidRectangleHasNoContact() {
        let valid = Rect(x: 0, y: 0, width: 10, height: 10)

        #expect(Rect.invalid.contact(with: valid) == nil)
        #expect(valid.contact(with: .invalid) == nil)
    }
}

@Suite
struct HorizontalCollisions {
    @Test
    func horizontalContactHasCorrectDepth() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 8, y: 0, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.depth == 2)
    }

    @Test
    func contactNormalPointsTowardsRectangleOnRight() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 8, y: 0, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.normal == .init(1, 0))
    }

    @Test
    func contactFromLeftHasCorrectDepth() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: -8, y: 0, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.depth == 2)
    }

    @Test
    func contactNormalPointsTowardsRectangleOnLeft() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: -8, y: 0, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.normal == .init(-1, 0))
    }
}

@Suite
struct VerticalCollisions {
    @Test
    func verticalContactHasCorrectDepth() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 0, y: 8, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.depth == 2)
    }

    @Test
    func contactNormalPointsTowardsRectangleAbove() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 0, y: 8, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.normal == .init(0, 1))
    }

    @Test
    func contactNormalPointsTowardsRectangleBelow() {
        let first = Rect(x: 0, y: 0, width: 10, height: 10)
        let second = Rect(x: 0, y: -8, width: 10, height: 10)

        let contact = first.contact(with: second)

        #expect(contact?.normal == .init(0, -1))
    }
}
