/// Each callback writes only its raw sample. Buffers support concurrent
/// producers without relying on Metal callback thread affinity.
nonisolated final class ProfileCapture: Sendable {
    let frames = ProfileBuffer<FrameProfile>()
    let gpuTimes = ProfileBuffer<Double?>()
    let presentations = ProfileBuffer<Double>()
}
