import Swift

public struct Buffer: Hashable, Sendable {
    package let id: ResourceID
    public let descriptor: BufferDescriptor

    package init(id: ResourceID, descriptor: BufferDescriptor) {
        self.id = id
        self.descriptor = descriptor
    }
}

public struct BufferDescriptor: Hashable, Sendable {
    public let size: UInt64
    public let usage: BufferUsage
    public let memory: BufferMemory

    public init(
        size: UInt64,
        usage: BufferUsage,
        memory: BufferMemory
    ) {
        precondition(size > 0, "Buffer size must be greater than zero")
        precondition(!usage.isEmpty, "Buffer usage must not be empty")

        self.size = size
        self.usage = usage
        self.memory = memory
    }
}

public enum BufferMemory: Hashable, Sendable {
    case gpuOnly
    case cpuVisible
    case gpuToCPU
}

public struct BufferUsage: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let vertex = Self(rawValue: 1 << 0)
    public static let index = Self(rawValue: 1 << 1)
    public static let uniform = Self(rawValue: 1 << 2)
    public static let storage = Self(rawValue: 1 << 3)
    public static let copySource = Self(rawValue: 1 << 4)
    public static let copyDestination = Self(rawValue: 1 << 5)
}
