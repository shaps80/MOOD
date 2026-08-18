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

    @Test
    func floatFunctionsExposeCommonMathOperations() {
        let value = Float(0.5)

        #expect(abs(tan(value) - 0.546_302_5) < 0.001)
        #expect(abs(atan(value) - 0.463_647_6) < 0.001)
        #expect(abs(acos(value) - 1.047_197_6) < 0.001)
        #expect(abs(exp(value) - 1.648_721_2) < 0.000_001)
    }

    @Test
    func doubleFunctionsExposeCommonMathOperations() {
        let value = Double(0.5)

        #expect(abs(tan(value) - 0.546_302_489_843_790_5) < 0.001)
        #expect(abs(atan(value) - 0.463_647_609_000_806_1) < 0.001)
        #expect(abs(acos(value) - 1.047_197_551_196_597_9) < 0.001)
        #expect(abs(exp(value) - 1.648_721_270_700_128_2) < 0.000_000_000_001)
    }
}
