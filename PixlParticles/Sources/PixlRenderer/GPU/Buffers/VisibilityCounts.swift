import Swift

/// One diagnostic count per workgroup, never an index per particle.
final class VisibilityCounts {
    static let threadCount = 128
    private(set) var generation: UInt64 = 0
    let buffer: any Buffer
    private(set) var blockCount = 0

    init?(platform: any Platform, capacity: Int) {
        guard let buffer = platform.makeBuffer(
            length: max(1, (capacity + Self.threadCount - 1) / Self.threadCount) * MemoryLayout<UInt32>.stride,
            memory: .cpuVisible
        ) else { return nil }
        self.buffer = buffer
    }

    var capturedCount: Int {
        var result = 0
        buffer.withMutableBytes { bytes in
            let counts = bytes.bindMemory(to: UInt32.self)
            for index in 0..<blockCount { result += Int(counts[index]) }
        }
        return result
    }

    func didSubmit(count: Int, generation: UInt64) {
        blockCount = (count + Self.threadCount - 1) / Self.threadCount
        self.generation = generation
    }
}
