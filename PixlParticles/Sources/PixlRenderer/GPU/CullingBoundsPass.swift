import Swift

final class CullingBoundsPass {
    private let pipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "cullingBoundsVertex",
                fragmentFunction: "cullingBoundsFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let depth = platform.makeDepthState(
            compare: .less,
            isWriteEnabled: false
        ) else {
            throw RenderError.pipeline
        }
        self.pipeline = pipeline
        self.depth = depth
    }

    func encode(
        bounds: CullingBounds,
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexValue(viewProjection, index: 0)
        encoder.setVertexValue(
            SIMD2<Float>(bounds.scale * 0.5, bounds.baseHeight),
            index: 1
        )
        encoder.drawPrimitives(.line, vertexStart: 0, vertexCount: 24)
    }
}
