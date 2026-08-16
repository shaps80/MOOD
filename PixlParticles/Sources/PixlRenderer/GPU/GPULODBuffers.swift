import Swift

@MainActor
struct GPULODBuffers {
    let tileCounts: any Buffer
    let visibleIndices: any Buffer
    let drawArguments: any Buffer
    let workArguments: any Buffer
    let clearArguments: any Buffer
    let state: any Buffer

    init?(
        platform: any Platform,
        particleCapacity: Int,
        tileCapacity: Int
    ) {
        let integer = MemoryLayout<UInt32>.stride
        guard let tileCounts = platform.makeBuffer(
            length: tileCapacity * integer,
            memory: .gpuOnly
        ), let visibleIndices = platform.makeBuffer(
            length: particleCapacity * integer,
            memory: .gpuOnly
        ), let drawArguments = platform.makeBuffer(
            length: 4 * integer,
            memory: .gpuOnly
        ), let workArguments = platform.makeBuffer(
            length: 3 * integer,
            memory: .gpuOnly
        ), let clearArguments = platform.makeBuffer(
            length: 3 * integer,
            memory: .gpuOnly
        ), let state = platform.makeBuffer(
            length: 4 * integer,
            memory: .gpuOnly
        ) else {
            return nil
        }
        self.tileCounts = tileCounts
        self.visibleIndices = visibleIndices
        self.drawArguments = drawArguments
        self.workArguments = workArguments
        self.clearArguments = clearArguments
        self.state = state
    }
}
