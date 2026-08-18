import Swift

package final class Renderer {
    private let backend: any Backend

    package init(backend: any Backend) {
        self.backend = backend
    }

    package func render(
        buffers: ParticleBuffers,
        count: Int,
        renderer: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame
    ) throws {
        try backend.renderParticles(
            count: count,
            buffers: buffers,
            renderer: renderer,
            values: values,
            interpolation: interpolation,
            cullingViewProjection: cullingViewProjection,
            camera: camera
        )
    }
}
