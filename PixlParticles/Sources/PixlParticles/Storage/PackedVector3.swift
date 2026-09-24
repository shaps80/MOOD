import PixlRenderer
import Swift

/// Three signed ten-bit fixed-point components, packed into one word.
/// The remaining two bits are reserved. Scale is shared by the emitter.
struct PackedVector3: Equatable, Sendable {
    let scale: Float

    init(maximumMagnitude: Float) {
        precondition(maximumMagnitude.isFinite && maximumMagnitude >= 0)
        guard maximumMagnitude > 0 else { scale = 1; return }
        let required = max(maximumMagnitude / 511, Float.leastNormalMagnitude)
        let power = Float(sign: .plus, exponent: required.exponent, significand: 1)
        let candidate = power < required ? power * 2 : power
        if (candidate * 511).isFinite {
            scale = candidate
        } else {
            // At the extreme Float32 range a power-of-two step would round
            // the largest component to infinity. Keep the endpoint finite.
            let endpointScale = Float.greatestFiniteMagnitude / 511
            scale = (endpointScale * 511).isFinite ? endpointScale : endpointScale.nextDown
        }
    }

    @inline(__always)
    func pack(_ value: Vec3) -> UInt32 {
        component(value.x) | (component(value.y) << 10) | (component(value.z) << 20)
    }

    @inline(__always)
    private func component(_ value: Float) -> UInt32 {
        let rounded = (value / scale).rounded(.toNearestOrAwayFromZero)
        precondition(rounded.isFinite && rounded >= -511 && rounded <= 511,
                     "Packed vector exceeds its compiled range")
        return UInt32(bitPattern: Int32(rounded)) & 0x3ff
    }

    @inline(__always)
    func unpack(_ word: UInt32) -> Vec3 {
        Vec3(
            Float(Int32(bitPattern: word << 22) >> 22),
            Float(Int32(bitPattern: word << 12) >> 22),
            Float(Int32(bitPattern: word << 2) >> 22)
        ) * scale
    }

    @inline(__always)
    func unpack(_ words: SIMD4<UInt32>) -> Vector3Batch {
        Vector3Batch(
            x: SIMD4<Float>(SIMD4<Int32>(truncatingIfNeeded: words &<< 22) &>> 22) * scale,
            y: SIMD4<Float>(SIMD4<Int32>(truncatingIfNeeded: words &<< 12) &>> 22) * scale,
            z: SIMD4<Float>(SIMD4<Int32>(truncatingIfNeeded: words &<< 2) &>> 22) * scale
        )
    }
}
