import Swift

final class BillboardPass {
    private let pipeline: any RenderPipeline
    private let depth: any DepthState

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "billboardVertex",
                fragmentFunction: "billboardFragment",
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
        self.depth = depth
    }

    func encode(
        displacements: any Buffer,
        displacementScale: Float,
        currentPositions: any Buffer,
        colorIndices: any Buffer,
        colorPalette: any Buffer,
        visibleIndices: any Buffer,
        indirectArguments: any Buffer,
        renderer: BillboardRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        camera: CameraFrame,
        into encoder: any RenderEncoder
    ) {
        let configuration = BillboardConfiguration(
            values: [values.size.x, values.size.y, values.rotation, 0],
            modes: [renderer.sizeSpace.gpuValue, renderer.facing.gpuValue, 0, 0]
        )
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexBuffer(displacements, index: 0)
        encoder.setVertexBuffer(visibleIndices, index: 1)
        encoder.setVertexValue(camera, index: 2)
        encoder.setVertexValue(interpolation, index: 3)
        encoder.setVertexValue(configuration, index: 4)
        encoder.setVertexBuffer(colorIndices, index: 6)
        encoder.setVertexBuffer(currentPositions, index: 7)
        encoder.setVertexValue(displacementScale, index: 8)
        encoder.setVertexBuffer(colorPalette, index: 9)
        encoder.drawPrimitives(
            .triangleStrip,
            indirectBuffer: indirectArguments
        )
    }
}

private struct BillboardConfiguration: BitwiseCopyable {
    let values: SIMD4<Float>
    let modes: SIMD4<UInt32>
}

extension BillboardRenderer.SizeSpace {
    var gpuValue: UInt32 {
        switch self {
        case .world: 0
        case .screen: 1
        }
    }
}

extension BillboardRenderer.Facing {
    var gpuValue: UInt32 {
        switch self {
        case .camera: 0
        case .cameraPlane: 1
        case .cameraPosition: 2
        }
    }
}
