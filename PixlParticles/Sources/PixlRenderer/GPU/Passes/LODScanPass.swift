import Swift

final class LODScanPass {
    private let scan: any ComputePipeline
    private let addOffsets: any ComputePipeline
    private let finish: any ComputePipeline

    init(platform: any Platform) throws {
        guard let scan = platform.makeComputePipeline(
            function: "scanPointLODBlockSums"
        ), let addOffsets = platform.makeComputePipeline(
            function: "addPointLODScanOffsets"
        ), let finish = platform.makeComputePipeline(
            function: "finishPointLODScan"
        ) else { throw RenderError.pipeline }
        self.scan = scan
        self.addOffsets = addOffsets
        self.finish = finish
    }

    func encode(
        maximumVisibleCount: UInt32,
        culling: CullingBuffers,
        lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        var divisor = CullingPass.threadCount
        try encodeLevel(
            input: culling.blockSums,
            offsets: culling.blockOffsets,
            sums: culling.scan.sums[0],
            divisor: divisor,
            groups: culling.scan.capacities[0],
            culling: culling,
            lod: lod,
            into: commandBuffer
        )

        for index in culling.scan.offsets.indices {
            divisor *= CullingPass.threadCount
            try encodeLevel(
                input: culling.scan.sums[index],
                offsets: culling.scan.offsets[index],
                sums: culling.scan.sums[index + 1],
                divisor: divisor,
                groups: culling.scan.capacities[index + 1],
                culling: culling,
                lod: lod,
                into: commandBuffer
            )
        }

        if culling.scan.offsets.count > 1 {
            for index in stride(
                from: culling.scan.offsets.count - 2,
                through: 0,
                by: -1
            ) {
                try encodeOffsetAddition(
                    offsets: culling.scan.offsets[index],
                    parent: culling.scan.offsets[index + 1],
                    divisor: Self.power(
                        CullingPass.threadCount,
                        index + 2
                    ),
                    count: culling.scan.capacities[index],
                    culling: culling,
                    lod: lod,
                    into: commandBuffer
                )
            }
        }
        if let parent = culling.scan.offsets.first {
            try encodeOffsetAddition(
                offsets: culling.blockOffsets,
                parent: parent,
                divisor: CullingPass.threadCount,
                count: culling.blockCapacity,
                culling: culling,
                lod: lod,
                into: commandBuffer
            )
        }

        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Finish Scan")
        encoder.setPipeline(finish)
        encoder.setBuffer(culling.scan.sums.last!, index: 0)
        encoder.setBuffer(lod.drawArguments, index: 1)
        encoder.setBuffer(lod.state, index: 2)
        encoder.setValue(maximumVisibleCount, index: 3)
        encoder.dispatchThreads(.init(width: 1), threads: .init(width: 1))
        encoder.endEncoding()
    }

    private func encodeLevel(
        input: any Buffer,
        offsets: any Buffer,
        sums: any Buffer,
        divisor: Int,
        groups: Int,
        culling: CullingBuffers,
        lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Parallel Scan")
        encoder.setPipeline(scan)
        encoder.setBuffer(input, index: 0)
        encoder.setBuffer(offsets, index: 1)
        encoder.setBuffer(sums, index: 2)
        encoder.setBuffer(culling.indirectArguments, index: 3)
        encoder.setBuffer(lod.state, index: 4)
        encoder.setValue(UInt32(divisor), index: 5)
        encoder.dispatchThreadgroups(
            .init(width: groups),
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeOffsetAddition(
        offsets: any Buffer,
        parent: any Buffer,
        divisor: Int,
        count: Int,
        culling: CullingBuffers,
        lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(
            commandBuffer,
            label: "Point LOD Add Scan Offsets"
        )
        encoder.setPipeline(addOffsets)
        encoder.setBuffer(offsets, index: 0)
        encoder.setBuffer(parent, index: 1)
        encoder.setBuffer(culling.indirectArguments, index: 2)
        encoder.setBuffer(lod.state, index: 3)
        encoder.setValue(UInt32(divisor), index: 4)
        encoder.dispatchThreads(
            .init(width: count),
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func makeEncoder(
        _ commandBuffer: any CommandBuffer,
        label: String
    ) throws -> any ComputeEncoder {
        guard let encoder = commandBuffer.makeComputeEncoder() else {
            throw RenderError.encoder
        }
        encoder.label = label
        return encoder
    }

    private static func power(_ base: Int, _ exponent: Int) -> Int {
        var result = 1
        for _ in 0..<exponent { result *= base }
        return result
    }
}
