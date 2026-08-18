import PixlRenderer
import Swift

public final class Renderer {
    private let renderer: PixlRenderer.Renderer

    public init(backend: any Backend) {
        renderer = .init(backend: backend)
    }

    public func render(
        _ system: System,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        try system.withRenderingData { buffers, count in
            try renderer.render(
                buffers: buffers,
                count: count,
                interpolation: interpolation,
                cullingViewProjection: cullingViewProjection,
                viewProjection: viewProjection,
                viewport: viewport
            )
        }
    }
}
