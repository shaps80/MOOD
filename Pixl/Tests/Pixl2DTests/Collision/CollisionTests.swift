import Pixl2D
import Testing

@Suite("Pixl2D collisions")
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
}
