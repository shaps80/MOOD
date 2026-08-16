import Swift

@MainActor
struct GPUCullingBuffers {
    let localOffsets: any Buffer
    let blockSums: any Buffer
    let blockOffsets: any Buffer
    let visibleIndices: any Buffer
    let indirectArguments: any Buffer

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
        ) else {
            return nil
        }

        self.localOffsets = localOffsets
        self.blockSums = blockSums
        self.blockOffsets = blockOffsets
        self.visibleIndices = visibleIndices
        self.indirectArguments = indirectArguments
    }
}
