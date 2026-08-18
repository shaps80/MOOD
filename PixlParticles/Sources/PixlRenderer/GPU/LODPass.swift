import Swift

final class LODPass {
    private let prepare: any ComputePipeline
    private let clear: any ComputePipeline
    private let count: any ComputePipeline
    private let thresholds: any ComputePipeline
    private let classify: any ComputePipeline
    private let scan: LODScanPass
    private let scatter: any ComputePipeline

    init(platform: any Platform) throws {
        guard let prepare = platform.makeComputePipeline(function: "preparePointLOD"),
              let clear = platform.makeComputePipeline(function: "clearPointLODTiles"),
              let count = platform.makeComputePipeline(function: "countPointLODTiles"),
              let thresholds = platform.makeComputePipeline(function: "preparePointLODThresholds"),
              let classify = platform.makeComputePipeline(function: "classifyPointLOD"),
              let scatter = platform.makeComputePipeline(function: "scatterPointLOD")
        else { throw RenderError.pipeline }
        self.prepare = prepare
        self.clear = clear
        self.count = count
        self.thresholds = thresholds
        self.classify = classify
        scan = try LODScanPass(platform: platform)
        self.scatter = scatter
    }

    func encode(
        settings: PointLOD,
        viewport: ViewportSize,
        interpolation: Float,
        viewProjection: Matrix4x4,
        previousPositions: any Buffer,
        currentPositions: any Buffer,
        ids: any Buffer,
        culling: CullingBuffers,
        lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let tileSize = UInt32(settings.tileSize)
        let columns = (viewport.width + tileSize - 1) / tileSize
        let rows = (viewport.height + tileSize - 1) / tileSize
        let configuration = LODConfiguration(
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
            previousPositions,
            currentPositions,
            culling,
            lod,
            into: commandBuffer
        )
        try encodeThresholds(configuration, culling, lod, into: commandBuffer)
        try encodeClassification(
            configuration,
            ids,
            culling,
            lod,
            into: commandBuffer
        )
        try scan.encode(
            maximumVisibleCount: configuration.maximumVisibleCount,
            culling: culling,
            lod: lod,
            into: commandBuffer
        )
        try encodeScatter(configuration, culling, lod, into: commandBuffer)
    }

    private func encodePrepare(
        _ configuration: LODConfiguration,
        _ culling: CullingBuffers,
        _ lod: LODBuffers,
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
        _ configuration: LODConfiguration,
        _ lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Clear Tiles")
        encoder.setPipeline(clear)
        encoder.setBuffer(lod.tileCounts, index: 0)
        encoder.setValue(configuration.tileCount, index: 1)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.clearArguments,
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeTileCount(
        _ configuration: LODConfiguration,
        _ interpolation: Float,
        _ viewProjection: Matrix4x4,
        _ previousPositions: any Buffer,
        _ currentPositions: any Buffer,
        _ culling: CullingBuffers,
        _ lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Count Tiles")
        encoder.setPipeline(count)
        encoder.setBuffer(previousPositions, index: 0)
        encoder.setBuffer(culling.visibleIndices, index: 1)
        encoder.setBuffer(culling.indirectArguments, index: 2)
        encoder.setBuffer(lod.tileCounts, index: 3)
        encoder.setBuffer(culling.localOffsets, index: 4)
        encoder.setValue(viewProjection, index: 5)
        encoder.setValue(interpolation, index: 6)
        encoder.setValue(configuration, index: 7)
        encoder.setBuffer(currentPositions, index: 8)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.workArguments,
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeThresholds(
        _ configuration: LODConfiguration,
        _ culling: CullingBuffers,
        _ lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Thresholds")
        encoder.setPipeline(thresholds)
        encoder.setBuffer(lod.tileCounts, index: 0)
        encoder.setBuffer(lod.tileThresholds, index: 1)
        encoder.setValue(configuration, index: 2)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.clearArguments,
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeClassification(
        _ configuration: LODConfiguration,
        _ ids: any Buffer,
        _ culling: CullingBuffers,
        _ lod: LODBuffers,
        into commandBuffer: any CommandBuffer
    ) throws {
        let encoder = try makeEncoder(commandBuffer, label: "Point LOD Classify")
        encoder.setPipeline(classify)
        encoder.setBuffer(ids, index: 0)
        encoder.setBuffer(culling.visibleIndices, index: 1)
        encoder.setBuffer(culling.indirectArguments, index: 2)
        encoder.setBuffer(lod.tileThresholds, index: 3)
        encoder.setBuffer(culling.localOffsets, index: 4)
        encoder.setBuffer(culling.blockSums, index: 5)
        encoder.setBuffer(lod.state, index: 6)
        encoder.dispatchThreadgroups(
            indirectBuffer: lod.workArguments,
            threads: .init(width: CullingPass.threadCount)
        )
        encoder.endEncoding()
    }

    private func encodeScatter(
        _ configuration: LODConfiguration,
        _ culling: CullingBuffers,
        _ lod: LODBuffers,
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
}

private struct LODConfiguration: BitwiseCopyable {
    let activationCount: UInt32
    let maximumVisibleCount: UInt32
    let tileSize: UInt32
    let targetPointsPerPixel: UInt32
    let viewportWidth: UInt32
    let viewportHeight: UInt32
    let tileColumns: UInt32
    let tileCount: UInt32
}
