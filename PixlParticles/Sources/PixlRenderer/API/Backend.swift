import Swift

public protocol Backend: AnyObject {
    func renderPoints(
        count: Int,
        buffers: PointBuffers,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws
}
