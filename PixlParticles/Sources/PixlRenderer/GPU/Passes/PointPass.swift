import Swift

final class PointPass {
    private let directPipeline: any RenderPipeline
    private let pipeline: any RenderPipeline
    private let lodPipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let directPipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "pointDirectVertex",
                fragmentFunction: "pointFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied,
                supportsReusableCommands: true
            )
        ), let pipeline = platform.makeRenderPipeline(
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
        self.directPipeline = directPipeline
        self.pipeline = pipeline
        self.lodPipeline = lodPipeline
        self.depth = depth
    }

    func encode(
        displacements: any Buffer,
        displacementScale: Float,
        currentPositions: any Buffer,
        colorIndices: any Buffer,
        colorPalette: any Buffer,
        visibleIndices: (any Buffer)?,
        indirectArguments: (any Buffer)?,
        count: Int,
        visibility: DirectVisibility,
        lod: LODBuffers?,
        interpolation: Float,
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        encoder.setPipeline(visibleIndices == nil ? directPipeline : (lod == nil ? pipeline : lodPipeline))
        encoder.setDepthState(depth)
        encoder.setVertexBuffer(displacements, index: 0)
        if let visibleIndices {
            encoder.setVertexBuffer(visibleIndices, index: 1)
        } else {
            encoder.setVertexValue(visibility, index: 10)
        }
        encoder.setVertexValue(viewProjection, index: 2)
        encoder.setVertexValue(interpolation, index: 3)
        encoder.setVertexBuffer(colorIndices, index: 6)
        encoder.setVertexBuffer(currentPositions, index: 7)
        encoder.setVertexValue(displacementScale, index: 8)
        encoder.setVertexBuffer(colorPalette, index: 9)
        if let lod {
            encoder.setVertexBuffer(lod.visibleIndices, index: 4)
            encoder.setVertexBuffer(lod.state, index: 5)
            encoder.drawPrimitives(.point, indirectBuffer: lod.drawArguments)
        } else if let indirectArguments {
            encoder.drawPrimitives(.point, indirectBuffer: indirectArguments)
        } else {
            encoder.drawReusablePrimitives(.point, vertexCount: count, instanceCount: 1)
        }
    }
}
