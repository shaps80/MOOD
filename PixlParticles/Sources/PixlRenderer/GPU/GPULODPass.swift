import Swift

@MainActor
final class GPULODPass {
    private let prepare: any ComputePipeline
    private let clear: any ComputePipeline
    private let count: any ComputePipeline
    private let classify: any ComputePipeline
    private let scan: any ComputePipeline
    private let scatter: any ComputePipeline

    init(platform: any Platform) throws {
        guard let prepare = platform.makeComputePipeline(function: "preparePointLOD"),
              let clear = platform.makeComputePipeline(function: "clearPointLODTiles"),
              let count = platform.makeComputePipeline(function: "countPointLODTiles"),
              let classify = platform.makeComputePipeline(function: "classifyPointLOD"),
              let scan = platform.makeComputePipeline(function: "scanPointLODBlocks"),
              let scatter = platform.makeComputePipeline(function: "scatterPointLOD")
        else { throw GPUError.pipeline }
        self.prepare = prepare
        self.clear = clear
        self.count = count
        self.classify = classify
        self.scan = scan
        self.scatter = scatter
    }

    func encode(
        settings: PointLOD,
        viewport: ViewportSize,
        interpolation: Float,
        viewProjection: Matrix4x4,
        positions: any Buffer,
        ids: any Buffer,
        culling: GPUCullingBuffers,
        lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let tileSize = UInt32(settings.tileSize)
        let columns = (viewport.width + tileSize - 1) / tileSize
        let rows = (viewport.height + tileSize - 1) / tileSize
        let configuration = GPULODConfiguration(
            activationCount: UInt32(settings.activationCount),
            maximumVisibleCount: UInt32(settings.maximumVisibleCount),
            tileSize: tileSize,
            targetPointsPerPixel: UInt32(
                max(
                    1,
                    min(
                        settings.targetPointsPerPixel * 65_536,
                        Float(UInt32.max)
                    )
                )
            ),
            viewportWidth: viewport.width,
            viewportHeight: viewport.height,
            tileColumns: columns,
            tileCount: columns * rows
        )

        try encodePrepare(configuration, culling, lod, into: commandBuffer)
        try encodeClear(configuration, lod, into: commandBuffer)
        try encodeTileCount(
            configuration,
            interpolation,
            viewProjection,
            positions,
            culling,
            lod,
            into: commandBuffer
        )
        try encodeClassification(
            configuration,
            interpolation,
            viewProjection,
            positions,
            ids,
            culling,
            lod,
            into: commandBuffer
        )
        try encodeScan(configuration, culling, lod, into: commandBuffer)
        try encodeScatter(configuration, culling, lod, into: commandBuffer)
    }

    private func encodePrepare(
        _ configuration: GPULODConfiguration,
        _ culling: GPUCullingBuffers,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Prepare")
        encoder.setPipeline(prepare)
        encoder.setBuffer(culling.indirectArguments, index: 0)
        encoder.setBuffer(lod.drawArguments, index: 1)
        encoder.setBuffer(lod.workArguments, index: 2)
        encoder.setBuffer(lod.clearArguments, index: 3)
        encoder.setBuffer(lod.state, index: 4)
        encoder.setValue(configuration, index: 5)
        encoder.dispatchThreads(.init(width: 1), threads: .init(width: 1))
        encoder.endEncoding()
    }

    private func encodeClear(
        _ configuration: GPULODConfiguration,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Clear Tiles")
        encoder.setPipeline(clear)
        encoder.setBuffer(lod.tileCounts, index: 0)
        encoder.setValue(configuration.tileCount, index: 1)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.clearArguments,
            threads: .init(width: GPUCullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeTileCount(
        _ configuration: GPULODConfiguration,
        _ interpolation: Float,
        _ viewProjection: Matrix4x4,
        _ positions: any Buffer,
        _ culling: GPUCullingBuffers,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Count Tiles")
        encoder.setPipeline(count)
        encoder.setBuffer(positions, index: 0)
        encoder.setBuffer(culling.visibleIndices, index: 1)
        encoder.setBuffer(culling.indirectArguments, index: 2)
        encoder.setBuffer(lod.tileCounts, index: 3)
        encoder.setValue(viewProjection, index: 4)
        encoder.setValue(interpolation, index: 5)
        encoder.setValue(configuration, index: 6)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.workArguments,
            threads: .init(width: GPUCullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeClassification(
        _ configuration: GPULODConfiguration,
        _ interpolation: Float,
        _ viewProjection: Matrix4x4,
        _ positions: any Buffer,
        _ ids: any Buffer,
        _ culling: GPUCullingBuffers,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Classify")
        encoder.setPipeline(classify)
        encoder.setBuffer(positions, index: 0)
        encoder.setBuffer(ids, index: 1)
        encoder.setBuffer(culling.visibleIndices, index: 2)
        encoder.setBuffer(culling.indirectArguments, index: 3)
        encoder.setBuffer(lod.tileCounts, index: 4)
        encoder.setBuffer(culling.localOffsets, index: 5)
        encoder.setBuffer(culling.blockSums, index: 6)
        encoder.setValue(viewProjection, index: 7)
        encoder.setValue(interpolation, index: 8)
        encoder.setValue(configuration, index: 9)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.workArguments,
            threads: .init(width: GPUCullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeScan(
        _ configuration: GPULODConfiguration,
        _ culling: GPUCullingBuffers,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Scan")
        encoder.setPipeline(scan)
        encoder.setBuffer(culling.blockSums, index: 0)
        encoder.setBuffer(culling.blockOffsets, index: 1)
        encoder.setBuffer(culling.indirectArguments, index: 2)
        encoder.setBuffer(lod.drawArguments, index: 3)
        encoder.setBuffer(lod.state, index: 4)
        encoder.setValue(configuration, index: 5)
        encoder.dispatchThreads(.init(width: 1), threads: .init(width: 1))
        encoder.endEncoding()
    }

    private func encodeScatter(
        _ configuration: GPULODConfiguration,
        _ culling: GPUCullingBuffers,
        _ lod: GPULODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Scatter")
        encoder.setPipeline(scatter)
        encoder.setBuffer(culling.localOffsets, index: 0)
        encoder.setBuffer(culling.blockOffsets, index: 1)
        encoder.setBuffer(culling.visibleIndices, index: 2)
        encoder.setBuffer(lod.visibleIndices, index: 3)
        encoder.setBuffer(culling.indirectArguments, index: 4)
        encoder.setValue(configuration.maximumVisibleCount, index: 5)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.workArguments,
            threads: .init(width: GPUCullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func makeEncoder(
        _ commandBuffer: any CommandBuffer,
        label: String
    ) throws -> any ComputeEncoder {
        guard let encoder = commandBuffer.makeComputeEncoder() else {
            throw GPUError.encoder
        }
        encoder.label = label
        return encoder
    }
}

private struct GPULODConfiguration: BitwiseCopyable {
    let activationCount: UInt32
    let maximumVisibleCount: UInt32
    let tileSize: UInt32
    let targetPointsPerPixel: UInt32
    let viewportWidth: UInt32
    let viewportHeight: UInt32
    let tileColumns: UInt32
    let tileCount: UInt32
}
