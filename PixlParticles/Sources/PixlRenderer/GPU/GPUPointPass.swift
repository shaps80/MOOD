import Swift

@MainActor
final class GPUPointPass {
    private let pipeline: any RenderPipeline
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
        ), let depth = platform.makeDepthState(
            compare: .less,
            isWriteEnabled: true
        ) else {
            throw GPUError.pipeline
        }
        self.pipeline = pipeline
        self.depth = depth
    }

    func encode(
        positions: any Buffer,
        visibleIndices: any Buffer,
        indirectArguments: any Buffer,
        interpolation: Float,
        viewProjection: Matrix4x4,
        target: any RenderTarget,
        into commandBuffer: any CommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeRenderEncoder(target: target) else {
            throw GPUError.encoder
        }
        encoder.label = "Point Draw"
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexBuffer(positions, index: 0)
        encoder.setVertexBuffer(visibleIndices, index: 1)
        encoder.setVertexValue(viewProjection, index: 2)
        encoder.setVertexValue(interpolation, index: 3)
        encoder.drawPrimitives(.point, indirectBuffer: indirectArguments)
        encoder.endEncoding()
    }
}
