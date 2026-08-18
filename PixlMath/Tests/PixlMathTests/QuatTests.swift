import PixlMath
import Testing

@Suite("Quat")
struct QuatTests {
    @Test
    func rotationPreservesVectorLength() {
        let rotation = Quat(angle: .pi / 2, axis: [0, 1, 0])
        let rotated = act(rotation, [0, 0, 1])

        #expect(abs(rotated.x - 1) < 0.000_01)
        #expect(abs(rotated.y) < 0.000_01)
        #expect(abs(rotated.z) < 0.000_01)
    }
}
