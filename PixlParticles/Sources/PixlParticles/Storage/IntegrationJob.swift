import PixlRenderer
import Swift

struct IntegrationJob {
    let source: UnsafeMutableBufferPointer<Vector3Batch>
    let destination: UnsafeMutableBufferPointer<Vector3Batch>
    let velocities: UnsafeMutableBufferPointer<Vector3Batch>
    let delta: Float
}
