import Swift

/// Raw usage statistics for an arena or scope.
public struct MemoryStatistics: Hashable, Sendable {
    public let reserved: ByteCount
    public let used: ByteCount
    public let peak: ByteCount

    public var unused: ByteCount {
        reserved - min(reserved, peak)
    }

    init(reserved: ByteCount, used: ByteCount, peak: ByteCount) {
        self.reserved = reserved
        self.used = used
        self.peak = peak
    }
}
