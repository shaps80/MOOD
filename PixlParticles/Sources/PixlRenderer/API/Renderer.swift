import Swift

package final class Renderer {
    private let backend: any Backend

    package init(backend: any Backend) {
        self.backend = backend
    }

    package func render(
        buffers: PointBuffers,
        count: Int,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        try backend.renderPoints(
            count: count,
            buffers: buffers,
            interpolation: interpolation,
            cullingViewProjection: cullingViewProjection,
            viewProjection: viewProjection,
            viewport: viewport
        )
    }
}
