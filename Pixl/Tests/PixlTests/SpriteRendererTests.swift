import Testing
@testable import Pixl

@Suite("Sprite renderer")
struct SpriteRendererTests {
    @Test
    func renderLayersSupportGameDefinedOrderingAndOffsets() {
        let background: RenderLayer = 0
        let player: RenderLayer = 100

        #expect(background < player)
        #expect(player + 50 == RenderLayer(150))
        #expect(player - 50 == RenderLayer(50))
    }

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
