import Swift

final class PointPass {
    private let pipeline: any RenderPipeline
    private let lodPipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "pointVertex",
                fragmentFunction: "pointFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let lodPipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "pointLODVertex",
                fragmentFunction: "pointFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let depth = platform.makeDepthState(
            compare: .less,
            isWriteEnabled: true
        ) else {
            throw RenderError.pipeline
        }
        self.pipeline = pipeline
        self.lodPipeline = lodPipeline
        self.depth = depth
    }

    func encode(
        positions: any Buffer,
        visibleIndices: any Buffer,
        indirectArguments: any Buffer,
        lod: LODBuffers?,
        interpolation: Float,
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        encoder.setPipeline(lod == nil ? pipeline : lodPipeline)
        encoder.setDepthState(depth)
        encoder.setVertexBuffer(positions, index: 0)
        encoder.setVertexBuffer(visibleIndices, index: 1)
        encoder.setVertexValue(viewProjection, index: 2)
        encoder.setVertexValue(interpolation, index: 3)
        if let lod {
            encoder.setVertexBuffer(lod.visibleIndices, index: 4)
            encoder.setVertexBuffer(lod.state, index: 5)
            encoder.drawPrimitives(.point, indirectBuffer: lod.drawArguments)
        } else {
            encoder.drawPrimitives(.point, indirectBuffer: indirectArguments)
        }
    }
}
