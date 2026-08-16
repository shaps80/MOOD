import Swift

final class CullingPass {
    static let threadCount = 256

    private let classify: any ComputePipeline
    private let scan: any ComputePipeline
    private let addOffsets: any ComputePipeline
    private let finishScan: any ComputePipeline
    private let scatter: any ComputePipeline

    init(platform: any Platform) throws {
        guard let classify = platform.makeComputePipeline(
            function: "classifyAndScanVisibility"
        ), let scan = platform.makeComputePipeline(
            function: "scanBlockSums"
        ), let addOffsets = platform.makeComputePipeline(
            function: "addScannedBlockOffsets"
        ), let finishScan = platform.makeComputePipeline(
            function: "finishVisibilityScan"
        ), let scatter = platform.makeComputePipeline(
            function: "scatterVisibleIndices"
        ) else {
            throw RenderError.pipeline
        }
        self.classify = classify
        self.scan = scan
        self.addOffsets = addOffsets
        self.finishScan = finishScan
        self.scatter = scatter
    }

    func encode(
        count: Int,
        interpolation: Float,
        viewProjection: Matrix4x4,
        cullingBounds: CullingBounds,
        positions: any Buffer,
        buffers: CullingBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let integerBlockCount = (count + Self.threadCount - 1)
            / Self.threadCount
        let particleCount = UInt32(count)
        let blockCount = UInt32(integerBlockCount)

        if particleCount > 0 {
            guard let encoder = commandBuffer.makeComputeEncoder() else {
                throw RenderError.encoder
            }
            encoder.label = "Culling Classify and Local Scan"
            encoder.setPipeline(classify)
            encoder.setBuffer(positions, index: 0)
            encoder.setBuffer(buffers.localOffsets, index: 1)
            encoder.setBuffer(buffers.blockSums, index: 2)
            encoder.setValue(viewProjection, index: 3)
            encoder.setValue(interpolation, index: 4)
            encoder.setValue(particleCount, index: 5)
            encoder.setValue(
                SIMD2<Float>(
                    cullingBounds.scale * 0.5,
                    cullingBounds.baseHeight
                ),
                index: 6
            )
            encoder.setValue(
                UInt32(cullingBounds.isEnabled ? 1 : 0),
                index: 7
            )
            encoder.dispatchThreadgroups(
                .init(width: Int(blockCount)),
                threads: .init(width: Self.threadCount)
            )
            encoder.endEncoding()
        }

        try encodeScan(
            blockCount: Int(blockCount),
            buffers: buffers,
            into: commandBuffer
        )

        if particleCount > 0 {
            guard let encoder = commandBuffer.makeComputeEncoder() else {
                throw RenderError.encoder
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

    private func encodeScan(
        blockCount: Int,
        buffers: CullingBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        var count = blockCount
        try encodeScanLevel(
            input: buffers.blockSums,
            offsets: buffers.blockOffsets,
            sums: buffers.scan.sums[0],
            count: count,
            into: commandBuffer
        )
        count = max((count + Self.threadCount - 1) / Self.threadCount, 1)

        for index in buffers.scan.offsets.indices {
            try encodeScanLevel(
                input: buffers.scan.sums[index],
                offsets: buffers.scan.offsets[index],
                sums: buffers.scan.sums[index + 1],
                count: count,
                into: commandBuffer
            )
            count = (count + Self.threadCount - 1) / Self.threadCount
        }

        if buffers.scan.offsets.count > 1 {
            for index in stride(
                from: buffers.scan.offsets.count - 2,
                through: 0,
                by: -1
            ) {
                try encodeOffsetAddition(
                    offsets: buffers.scan.offsets[index],
                    parent: buffers.scan.offsets[index + 1],
                    count: buffers.scan.capacities[index],
                    into: commandBuffer
                )
            }
        }
        if let parent = buffers.scan.offsets.first {
            try encodeOffsetAddition(
                offsets: buffers.blockOffsets,
                parent: parent,
                count: blockCount,
                into: commandBuffer
            )
        }

        guard let encoder = commandBuffer.makeComputeEncoder() else {
            throw RenderError.encoder
        }
        encoder.label = "Culling Finish Scan"
        encoder.setPipeline(finishScan)
        encoder.setBuffer(buffers.scan.sums.last!, index: 0)
        encoder.setBuffer(buffers.indirectArguments, index: 1)
        encoder.dispatchThreads(.init(width: 1), threads: .init(width: 1))
        encoder.endEncoding()
    }

    private func encodeScanLevel(
        input: any Buffer,
        offsets: any Buffer,
        sums: any Buffer,
        count: Int,
        into commandBuffer: any CommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeEncoder() else {
            throw RenderError.encoder
        }
        encoder.label = "Culling Parallel Scan"
        encoder.setPipeline(scan)
        encoder.setBuffer(input, index: 0)
        encoder.setBuffer(offsets, index: 1)
        encoder.setBuffer(sums, index: 2)
        encoder.setValue(UInt32(count), index: 3)
        encoder.dispatchThreadgroups(
            .init(width: max((count + Self.threadCount - 1) / Self.threadCount, 1)),
            threads: .init(width: Self.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeOffsetAddition(
        offsets: any Buffer,
        parent: any Buffer,
        count: Int,
        into commandBuffer: any CommandBuffer
    ) throws {
        guard count > 0 else { return }
        guard let encoder = commandBuffer.makeComputeEncoder() else {
            throw RenderError.encoder
        }
        encoder.label = "Culling Add Scan Offsets"
        encoder.setPipeline(addOffsets)
        encoder.setBuffer(offsets, index: 0)
        encoder.setBuffer(parent, index: 1)
        encoder.setValue(UInt32(count), index: 2)
        encoder.dispatchThreads(
            .init(width: count),
            threads: .init(width: Self.threadCount)
        )
        encoder.endEncoding()
    }
}
