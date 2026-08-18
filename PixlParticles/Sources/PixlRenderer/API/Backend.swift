import Swift

public protocol Backend: AnyObject {
    func renderParticles(
        count: Int,
        buffers: ParticleBuffers,
        renderer: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame
    ) throws
}
