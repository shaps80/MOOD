import Swift

/// One diagnostic count per workgroup, never an index per particle.
final class VisibilityCounts {
    let buffer: any Buffer
    private(set) var blockCount = 0

    init?(platform: any Platform, capacity: Int) {
        guard let buffer = platform.makeBuffer(
            length: max(1, (capacity + 255) / 256) * MemoryLayout<UInt32>.stride,
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

    func didSubmit(count: Int) { blockCount = (count + 255) / 256 }
}
