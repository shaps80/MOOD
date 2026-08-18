import Swift

public final class HostBuffer {
    private static let alignment = 16_384

    public let byteCount: Int
    public let allocatedByteCount: Int

    private let storage: UnsafeMutableRawPointer

    public init(byteCount: Int) {
        precondition(byteCount >= 0)

        self.byteCount = byteCount
        allocatedByteCount = max(
            Self.alignment,
            (byteCount + Self.alignment - 1) / Self.alignment * Self.alignment
        )
        storage = .allocate(
            byteCount: allocatedByteCount,
            alignment: Self.alignment
        )
    }

    deinit {
        storage.deallocate()
    }

    public func withUnsafeBytes<Result: ~Copyable>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try body(.init(start: storage, count: byteCount))
    }

    package func withUnsafeMutableAllocatedBytes<Result: ~Copyable>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try body(.init(start: storage, count: allocatedByteCount))
    }

    package func mutableBuffer<Element>(
        of type: Element.Type,
        count: Int
    ) -> UnsafeMutableBufferPointer<Element> {
        precondition(count * MemoryLayout<Element>.stride <= byteCount)
        return .init(
            start: storage.assumingMemoryBound(to: Element.self),
            count: count
        )
    }

    package func bindMemory<Element>(
        to type: Element.Type,
        count: Int
    ) -> UnsafeMutableBufferPointer<Element> {
        precondition(count * MemoryLayout<Element>.stride <= byteCount)
        return .init(
            start: storage.bindMemory(to: Element.self, capacity: count),
            count: count
        )
    }
}
