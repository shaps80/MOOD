import Testing
@testable import PixlParticles

@Suite("Deterministic trigonometry")
struct DeterministicTrigTests {
    @Test("Sin and cosine match canonical angles")
    func canonicalSinCos() {
        let cases: [(angle: Float, cosine: Float, sine: Float)] = [
            (0, 1, 0),
            (0.5 * .pi, 0, 1),
            (.pi, -1, 0),
            (-0.5 * .pi, 0, -1),
            (-Float.pi, -1, 0)
        ]

        for value in cases {
            let result = sinCos(value.angle)
            #expect(abs(result.cosine - value.cosine) < 0.000_001)
            #expect(abs(result.sine - value.sine) < 0.000_001)
            #expect(cos(value.angle) == result.cosine)
            #expect(sin(value.angle) == result.sine)
        }
    }

    @Test("Supports Float and Double without changing the Float implementation")
    func scalarTypes() {
        let float: SinCos<Float> = sinCos(.pi / 3)
        let double: SinCos<Double> = sinCos(.pi / 3)

        #expect(abs(float.cosine - 0.5) < 0.001)
        #expect(abs(double.cosine - 0.5) < 0.001)
    }

    @Test("Sin and cosine remain normalized across the circle")
    func normalizedSinCos() {
        for index in 0...65_536 {
            let fraction = Float(index) / 65_536
            let angle = -Float.pi + fraction * 2 * .pi
            let result = sinCos(angle)
            let magnitudeSquared = result.cosine * result.cosine + result.sine * result.sine

            #expect(abs(magnitudeSquared - 1) < 0.000_001)
        }
    }

    @Test("Atan2 matches canonical directions")
    func canonicalAtan2() {
        let cases: [(y: Float, x: Float, angle: Float)] = [
            (0, 0, 0),
            (0, 1, 0),
            (1, 0, 0.5 * .pi),
            (0, -1, .pi),
            (-1, 0, -0.5 * .pi),
            (1, 1, 0.25 * .pi),
            (1, -1, 0.75 * .pi),
            (-1, -1, -0.75 * .pi),
            (-1, 1, -0.25 * .pi)
        ]

        for value in cases {
            let result = atan2(y: value.y, x: value.x)
            #expect(abs(result - value.angle) < 0.000_05)
        }
    }

    @Test("Atan matches canonical values")
    func canonicalAtan() {
        #expect(atan(Float.zero) == 0)
        #expect(abs(atan(Float(1)) - 0.25 * .pi) < 0.000_05)
        #expect(abs(atan(Float(-1)) + 0.25 * .pi) < 0.000_05)
        #expect(abs(atan(Double(1)) - 0.25 * .pi) < 0.000_05)
    }

    @Test("Sin and cosine unwind angles across turns")
    func unwoundSinCos() {
        let cases: [(input: Float, expected: Float)] = [
            (0, 0),
            (2.5 * .pi, 0.5 * .pi),
            (-2.5 * .pi, -0.5 * .pi),
            (8.25 * .pi, 0.25 * .pi)
        ]

        for value in cases {
            let result = sinCos(value.input)
            let expected = sinCos(value.expected)
            #expect(abs(result.cosine - expected.cosine) < 0.000_002)
            #expect(abs(result.sine - expected.sine) < 0.000_002)
        }
    }

    @Test("Matches stable bit patterns")
    func stableBitPatterns() {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for index in 0..<65_536 {
            let angle = Float(index - 32_768) / 256
            let result = sinCos(angle)
            let atan = atan2(
                y: result.sine * Float(index + 1),
                x: result.cosine * Float(65_536 - index)
            )

            hash = mix(result.cosine.bitPattern, into: hash)
            hash = mix(result.sine.bitPattern, into: hash)
            hash = mix(atan.bitPattern, into: hash)
        }

        // Generated independently from the upstream Box3D C implementation.
        #expect(hash == 0x068AC75AF4E0FA16)
    }

    @Test("Double matches stable bit patterns")
    func stableDoubleBitPatterns() {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for index in 0..<65_536 {
            let angle = Double(index - 32_768) / 256
            let result = sinCos(angle)
            let atan = atan2(
                y: result.sine * Double(index + 1),
                x: result.cosine * Double(65_536 - index)
            )

            hash = mix(result.cosine.bitPattern, into: hash)
            hash = mix(result.sine.bitPattern, into: hash)
            hash = mix(atan.bitPattern, into: hash)
        }

        #expect(hash == 0x07A228BF62042195)
    }

    private func mix(_ word: UInt32, into hash: UInt64) -> UInt64 {
        (hash ^ UInt64(word)) &* 1_099_511_628_211
    }

    private func mix(_ word: UInt64, into hash: UInt64) -> UInt64 {
        (hash ^ word) &* 1_099_511_628_211
    }
}
