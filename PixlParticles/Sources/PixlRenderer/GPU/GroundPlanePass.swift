import Swift

final class GroundPlanePass {
    private struct Uniforms: BitwiseCopyable {
        let viewProjection: Matrix4x4
        let dimensions: SIMD4<Float>
    }

    private let grid: any RenderPipeline
    private let horizon: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let grid = platform.makeRenderPipeline(
            .init(
                vertexFunction: "groundPlaneGridVertex",
                fragmentFunction: "groundPlaneFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let horizon = platform.makeRenderPipeline(
            .init(
                vertexFunction: "groundPlaneHorizonVertex",
                fragmentFunction: "groundPlaneFragment",
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
        self.grid = grid
        self.horizon = horizon
        self.depth = depth
    }

    func encode(
        settings: GroundPlane,
        into encoder: any RenderEncoder
    ) {
        let uniforms = Uniforms(
            viewProjection: settings.viewProjection,
            dimensions: [
                settings.height,
                settings.extent,
                settings.spacing,
                0,
            ]
        )
        encoder.setDepthState(depth)
        encoder.setVertexValue(uniforms, index: 0)

        switch settings.style {
        case .grid:
            encoder.setPipeline(grid)
            let lineCount = Int(settings.extent * 2 / settings.spacing) + 1
            encoder.drawPrimitives(
                .line,
                vertexStart: 0,
                vertexCount: lineCount * 4
            )
        case .horizon:
            encoder.setPipeline(horizon)
            encoder.drawPrimitives(.line, vertexStart: 0, vertexCount: 2)
        }
    }
}
