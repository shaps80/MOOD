import PixlRenderer
import Swift

final class GuidePass {
    private static let gridDivisions = 16
    private static let rayVertexCount = 4 * (gridDivisions + 1) * 2

    private struct Uniforms: BitwiseCopyable {
        let viewProjection: Matrix4x4
        let ground: SIMD4<Float>
        let inverseFrustumViewProjection: Matrix4x4
        let frustumOrigin: SIMD4<Float>
        let counts: SIMD4<UInt32>
    }

    private let pipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "editorGuideVertex",
                fragmentFunction: "editorGuideFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let depth = platform.makeDepthState(
            compare: .less,
            isWriteEnabled: false
        ) else {
            throw EditorSupportError.pipeline
        }
        self.pipeline = pipeline
        self.depth = depth
    }

    func encode(frame: Frame, into encoder: any RenderEncoder) {
        let groundVertexCount = Self.groundVertexCount(frame.groundPlane)
        let rayVertexCount = frame.cameraFrustum.isVisible
            ? Self.rayVertexCount
            : 0
        let vertexCount = groundVertexCount + rayVertexCount
        guard vertexCount > 0 else { return }

        let frustum = frame.cameraFrustum
        let uniforms = Uniforms(
            viewProjection: frame.viewProjection,
            ground: [
                frame.groundPlane.height,
                frame.groundPlane.extent,
                frame.groundPlane.spacing,
                0,
            ],
            inverseFrustumViewProjection: frustum.inverseViewProjection,
            frustumOrigin: SIMD4<Float>(frustum.position, 1),
            counts: [
                UInt32(groundVertexCount),
                frame.groundPlane.style.rawValue,
                UInt32(frustum.isPerspective ? 1 : 0),
                UInt32(Self.gridDivisions),
            ]
        )
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexValue(uniforms, index: 0)
        encoder.drawPrimitives(
            .line,
            vertexStart: 0,
            vertexCount: vertexCount
        )
    }

    private static func groundVertexCount(_ ground: GroundPlane) -> Int {
        guard ground.isVisible else { return 0 }
        switch ground.style {
        case .grid:
            let lineCount = Int(ground.extent * 2 / ground.spacing) + 1
            return lineCount * 4
        case .horizon:
            return 2
        }
    }
}
