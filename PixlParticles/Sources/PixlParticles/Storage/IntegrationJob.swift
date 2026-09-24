import PixlRenderer
import Swift

struct IntegrationJob {
    let positions: UnsafeMutableBufferPointer<Vector3Batch>
    let displacements: UnsafeMutableBufferPointer<SIMD4<UInt32>>
    let velocities: UnsafeMutableBufferPointer<SIMD4<UInt32>>
    let codec: PackedVector3
    let delta: Float

    @inline(__always)
    func run(_ range: Range<Int>) {
        for index in range {
            let words = velocities[index]
            let velocity = codec.unpack(words)
            positions[index].x += velocity.x * delta
            positions[index].y += velocity.y * delta
            positions[index].z += velocity.z * delta
            displacements[index] = words
        }
    }
}
