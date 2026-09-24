import Testing
@testable import PixlParticles

struct PackedVector3Tests {
    @Test func signedComponentsAndSIMDLanes() {
        let codec = PackedVector3(maximumMagnitude: 511)
        let values: [Vec3] = [[-511, 0, 511], [-1, 1, -2], [127, -128, 255], [0, 0, 0]]
        var words = SIMD4<UInt32>.zero
        for lane in 0..<4 {
            words[lane] = codec.pack(values[lane])
            #expect(words[lane] >> 30 == 0)
            #expect(codec.unpack(words[lane]) == values[lane])
        }
        let decoded = codec.unpack(words)
        for lane in 0..<4 { #expect(decoded[lane] == values[lane]) }
    }

    @Test func quantizationBoundsAndIdempotence() {
        for magnitude: Float in [0, 0.00001, 1, 20, 511, 100_000, Float.greatestFiniteMagnitude] {
            let codec = PackedVector3(maximumMagnitude: magnitude)
            for fraction: Float in [-1, -0.753, -0.001, 0, 0.001, 0.753, 1] {
                let value = Vec3(repeating: magnitude * fraction)
                let word = codec.pack(value)
                let decoded = codec.unpack(word)
                #expect(decoded.x.isFinite)
                #expect(abs(decoded.x - value.x) <= codec.scale * 0.501)
                #expect(codec.pack(decoded) == word)
            }
        }
    }
}
