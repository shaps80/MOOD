import Swift

@MainActor
final class GPUCullingPass {
    static let threadCount = 256

    private let classify: any ComputePipeline
    private let scan: any ComputePipeline
    private let scatter: any ComputePipeline

    init(platform: any Platform) throws {
        guard let classify = platform.makeComputePipeline(
            function: "classifyAndScanVisibility"
        ), let scan = platform.makeComputePipeline(
            function: "scanVisibilityBlocks"
        ), let scatter = platform.makeComputePipeline(
            function: "scatterVisibleIndices"
        ) else {
            throw GPUError.pipeline
        }
        self.classify = classify
        self.scan = scan
        self.scatter = scatter
    }

    func encode(
        count: Int,
        interpolation: Float,
        viewProjection: Matrix4x4,
        positions: any Buffer,
        buffers: GPUCullingBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let integerBlockCount = (count + Self.threadCount - 1)
            / Self.threadCount
        let particleCount = UInt32(count)
        let blockCount = UInt32(integerBlockCount)

        if particleCount > 0 {
            guard let encoder = commandBuffer.makeComputeEncoder() else {
                throw GPUError.encoder
            }
            encoder.label = "Culling Classify and Local Scan"
            encoder.setPipeline(classify)
            encoder.setBuffer(positions, index: 0)
            encoder.setBuffer(buffers.localOffsets, index: 1)
            encoder.setBuffer(buffers.blockSums, index: 2)
            encoder.setValue(viewProjection, index: 3)
            encoder.setValue(interpolation, index: 4)
            encoder.setValue(particleCount, index: 5)
            encoder.dispatchThreadgroups(
                .init(width: Int(blockCount)),
                threads: .init(width: Self.threadCount)
            )
            encoder.endEncoding()
        }

        guard let scanEncoder = commandBuffer.makeComputeEncoder() else {
            throw GPUError.encoder
        }
        scanEncoder.label = "Culling Block Scan"
        scanEncoder.setPipeline(scan)
        scanEncoder.setBuffer(buffers.blockSums, index: 0)
        scanEncoder.setBuffer(buffers.blockOffsets, index: 1)
        scanEncoder.setBuffer(buffers.indirectArguments, index: 2)
        scanEncoder.setValue(blockCount, index: 3)
        scanEncoder.dispatchThreads(.init(width: 1), threads: .init(width: 1))
        scanEncoder.endEncoding()

        if particleCount > 0 {
            guard let encoder = commandBuffer.makeComputeEncoder() else {
                throw GPUError.encoder
            }
            encoder.label = "Culling Scatter"
            encoder.setPipeline(scatter)
            encoder.setBuffer(buffers.localOffsets, index: 0)
            encoder.setBuffer(buffers.blockOffsets, index: 1)
            encoder.setBuffer(buffers.visibleIndices, index: 2)
            encoder.setValue(particleCount, index: 3)
            encoder.dispatchThreads(
                .init(width: Int(particleCount)),
                threads: .init(width: Self.threadCount)
            )
            encoder.endEncoding()
        }
    }
}
