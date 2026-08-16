import Swift

struct ScanBuffers {
    let sums: [any Buffer]
    let offsets: [any Buffer]
    let capacities: [Int]

    init?(
        platform: any Platform,
        blockCapacity: Int,
        threadCount: Int
    ) {
        var sums: [any Buffer] = []
        var offsets: [any Buffer] = []
        var capacities: [Int] = []
        var count = (blockCapacity + threadCount - 1) / threadCount
        let integer = MemoryLayout<UInt32>.stride

        while count > 0 {
            guard let sum = platform.makeBuffer(
                length: count * integer,
                memory: .gpuOnly
            ) else { return nil }
            sums.append(sum)
            capacities.append(count)

            guard count > 1 else { break }
            guard let offset = platform.makeBuffer(
                length: count * integer,
                memory: .gpuOnly
            ) else { return nil }
            offsets.append(offset)
            count = (count + threadCount - 1) / threadCount
        }

        self.sums = sums
        self.offsets = offsets
        self.capacities = capacities
    }
}
