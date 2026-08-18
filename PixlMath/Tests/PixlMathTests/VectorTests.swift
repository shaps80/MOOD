import PixlMath
import Testing

@Suite("Vector math")
struct VectorTests {
    @Test
    func products() {
        let x = SIMD3<Float>(1, 0, 0)
        let y = SIMD3<Float>(0, 1, 0)

        #expect(dot(x, y) == 0)
        #expect(cross(x, y) == SIMD3<Float>(0, 0, 1))
    }

    @Test
    func normalizationAndMixing() {
        #expect(normalize(SIMD3<Float>(0, 3, 0)) == SIMD3<Float>(0, 1, 0))
        #expect(mix(Float(2), 4, 0.25) == 2.5)
        #expect(
            mix(SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 4), 0.25)
                == SIMD3<Float>(repeating: 1)
        )
    }
}
