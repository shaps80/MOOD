import Swift

struct CullingBuffers {
    let blockCapacity: Int
    let localOffsets: any Buffer
    let blockSums: any Buffer
    let blockOffsets: any Buffer
    let visibleIndices: any Buffer
    let indirectArguments: any Buffer
    let diagnosticCount: any Buffer
    let scan: ScanBuffers

    init?(
        platform: any Platform,
        particleCapacity: Int,
        blockCapacity: Int
    ) {
        let integer = MemoryLayout<UInt32>.stride
        guard let localOffsets = platform.makeBuffer(
            length: particleCapacity * integer,
            memory: .gpuOnly
        ), let blockSums = platform.makeBuffer(
            length: blockCapacity * integer,
            memory: .gpuOnly
        ), let blockOffsets = platform.makeBuffer(
            length: blockCapacity * integer,
            memory: .gpuOnly
        ), let visibleIndices = platform.makeBuffer(
            length: particleCapacity * integer,
            memory: .gpuOnly
        ), let indirectArguments = platform.makeBuffer(
            length: 4 * integer,
            memory: .gpuOnly
        ), let diagnosticCount = platform.makeBuffer(
            length: integer,
            memory: .cpuVisible
        ), let scan = ScanBuffers(
            platform: platform,
            blockCapacity: blockCapacity,
            threadCount: CullingPass.threadCount
        ) else {
            return nil
        }

        self.blockCapacity = blockCapacity
        self.localOffsets = localOffsets
        self.blockSums = blockSums
        self.blockOffsets = blockOffsets
        self.visibleIndices = visibleIndices
        self.indirectArguments = indirectArguments
        self.diagnosticCount = diagnosticCount
        self.scan = scan
        diagnosticCount.withMutableBytes { bytes in
            bytes.storeBytes(of: UInt32.zero, as: UInt32.self)
        }
    }

    var capturedVisibleCount: Int {
        var count: UInt32 = 0
        diagnosticCount.withMutableBytes { bytes in
            count = bytes.load(as: UInt32.self)
        }
        return Int(count)
    }
}
