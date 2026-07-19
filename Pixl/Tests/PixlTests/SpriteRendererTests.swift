import Pixl2D
import Testing
@testable import Pixl

@Suite("Sprite renderer")
struct SpriteRendererTests {
    @Test
    func submissionOrderIsStableWithinEachLayer() {
        let orders = [
            SpriteSubmissionOrder(layer: 10, ordinal: 0),
            SpriteSubmissionOrder(layer: 0, ordinal: 1),
            SpriteSubmissionOrder(layer: 10, ordinal: 2),
            SpriteSubmissionOrder(layer: 0, ordinal: 3),
        ].sorted()

        #expect(orders.map(\.layer) == [0, 0, 10, 10])
        #expect(orders.map(\.ordinal) == [1, 3, 0, 2])
    }
}
