import Swift

final class CameraFrustumPass {
    private static let gridDivisions = 16
    private static let rayVertexCount = 4 * (gridDivisions + 1) * 2
    private static let edgeVertexCount = 12 * 2
    private static let vertexCount = rayVertexCount + edgeVertexCount

    private let pipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "cameraFrustumVertex",
                fragmentFunction: "cameraFrustumFragment",
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
        frustum: CameraFrustum,
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexValue(viewProjection, index: 0)
        encoder.setVertexValue(frustum.inverseViewProjection, index: 1)
        encoder.setVertexValue(frustum.position, index: 2)
        encoder.setVertexValue(UInt32(frustum.isPerspective ? 1 : 0), index: 3)
        encoder.setVertexValue(UInt32(Self.gridDivisions), index: 4)
        encoder.drawPrimitives(
            .line,
            vertexStart: 0,
            vertexCount: Self.vertexCount
        )
    }
}
