import Swift

package enum ShaderArtifactFormat {
    case metalLibrary
    case wgsl
}

public final class Shader: @unchecked Sendable {
    private let storage: UnsafeMutableRawPointer
    public let byteCount: Int
    private let wgslSource: String?

    public init(copying bytes: UnsafeRawBufferPointer) {
        precondition(!bytes.isEmpty, "Shader bytes must not be empty")

        byteCount = bytes.count
        wgslSource = nil
        storage = .allocate(byteCount: bytes.count, alignment: 1)
        storage.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    }

    public init(
        copyingMetal bytes: UnsafeRawBufferPointer,
        wgslSource: String
    ) {
        precondition(!bytes.isEmpty, "Shader bytes must not be empty")
        precondition(!wgslSource.isEmpty, "WGSL shader source must not be empty")

        byteCount = bytes.count
        self.wgslSource = wgslSource
        storage = .allocate(byteCount: bytes.count, alignment: 1)
        storage.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    }

    public init(wgslSource: String) {
        precondition(!wgslSource.isEmpty, "WGSL shader source must not be empty")
        byteCount = 0
        self.wgslSource = wgslSource
        storage = .allocate(byteCount: 1, alignment: 1)
    }

    deinit {
        storage.deallocate()
    }

    package func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try body(.init(start: storage, count: byteCount))
    }


    package func source(for format: ShaderArtifactFormat) -> String? {
        switch format {
        case .wgsl: wgslSource
        case .metalLibrary: nil
        }
    }
}

public protocol ShaderLibrary: AnyObject {}
