import PixlMath
import Testing

@Suite("PixlMath")
struct MathTests {
    @Test
    func sinCosMatchesIndividualFunctions() {
        let angle = Float.pi / 4
        let value = sinCos(angle)

        #expect(abs(value.sine - sin(angle)) < 0.000_001)
        #expect(abs(value.cosine - cos(angle)) < 0.000_001)
    }

    @Test
    func doubleSinCosMatchesIndividualFunctions() {
        let angle = Double.pi / 4
        let value = sinCos(angle)

        #expect(abs(value.sine - sin(angle)) < 0.000_000_000_001)
        #expect(abs(value.cosine - cos(angle)) < 0.000_000_000_001)
    }
}
