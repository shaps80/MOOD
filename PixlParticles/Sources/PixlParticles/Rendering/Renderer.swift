import PixlRenderer
import Swift

public final class Renderer {
    private let renderer: PixlRenderer.Renderer

    public init(backend: any Backend) {
        renderer = .init(backend: backend)
    }

    public func render(
        _ system: System,
        renderer definition: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame
    ) throws {
        try system.withRenderingData { buffers, count in
            try renderer.render(
                buffers: buffers,
                count: count,
                renderer: definition,
                values: values,
                interpolation: interpolation,
                cullingViewProjection: cullingViewProjection,
                camera: camera
            )
        }
    }
}
