import Swift

public final class Shader {
    private let storage: UnsafeMutableRawPointer
    public let byteCount: Int

    public init(copying bytes: UnsafeRawBufferPointer) {
        precondition(!bytes.isEmpty, "Shader bytes must not be empty")

        byteCount = bytes.count
        storage = .allocate(byteCount: bytes.count, alignment: 1)
        storage.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    }

    deinit {
        storage.deallocate()
    }

    package func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try body(.init(start: storage, count: byteCount))
    }
}

public protocol ShaderLibrary: AnyObject {}
