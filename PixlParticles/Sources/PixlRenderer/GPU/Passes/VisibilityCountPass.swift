import Swift

final class VisibilityCountPass {
    private let pipeline: any ComputePipeline

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeComputePipeline(function: "countDirectVisibility")
        else { throw RenderError.pipeline }
        self.pipeline = pipeline
    }

    func encode(count: Int, visibility: DirectVisibility, interpolation: Float,
                displacementScale: Float, displacements: any Buffer,
                currentPositions: any Buffer, counts: VisibilityCounts,
                into commandBuffer: any CommandBuffer) throws {
        guard count > 0 else { return }
        guard let encoder = commandBuffer.makeComputeEncoder(timing: .diagnostics)
        else { throw RenderError.encoder }
        encoder.label = "Count Direct Visibility"
        encoder.setPipeline(pipeline)
        encoder.setBuffer(displacements, index: 0)
        encoder.setBuffer(currentPositions, index: 1)
        encoder.setBuffer(counts.buffer, index: 2)
        encoder.setValue(visibility, index: 3)
        encoder.setValue(interpolation, index: 4)
        encoder.setValue(displacementScale, index: 5)
        encoder.setValue(UInt32(count), index: 6)
        encoder.dispatchThreadgroups(.init(width: (count + 255) / 256), threads: .init(width: 256))
        encoder.endEncoding()
    }
}
