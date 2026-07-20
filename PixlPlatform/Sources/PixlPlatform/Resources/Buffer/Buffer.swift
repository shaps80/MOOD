import Swift

/// An opaque handle to a GPU buffer allocation.
public struct Buffer: Hashable, Sendable {
    package let id: ResourceID
    /// Description used to create the complete allocation.
    public let descriptor: BufferDescriptor

    package init(id: ResourceID, descriptor: BufferDescriptor) {
        self.id = id
        self.descriptor = descriptor
    }
}

/// Size, allowed roles, and memory intent for a complete buffer allocation.
public struct BufferDescriptor: Hashable, Sendable {
    /// Allocation size in bytes.
    public let size: UInt64
    /// Roles in which the buffer may be bound or copied.
    public let usage: BufferUsage
    /// Intended CPU/GPU visibility.
    public let memory: BufferMemory

    /// Creates a buffer description.
    /// - Parameters:
    ///   - size: Positive allocation size in bytes.
    ///   - usage: Nonempty set of allowed roles.
    ///   - memory: Intended CPU/GPU visibility.
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

/// Portable allocation intent for a buffer's CPU/GPU visibility.
public enum BufferMemory: Hashable, Sendable {
    /// Optimized for GPU access without direct CPU access.
    case gpuOnly
    /// Accessible by the CPU for uploads and by the GPU.
    case cpuVisible
    /// Intended for GPU writes followed by CPU reads.
    case gpuToCPU
}

/// Roles permitted for a buffer allocation.
public struct BufferUsage: OptionSet, Hashable, Sendable {
    /// Raw usage bitmask.
    public let rawValue: UInt32

    /// Creates usage roles from a raw bitmask.
    /// - Parameter rawValue: Bitmask composed from ``BufferUsage`` constants.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Supplies vertex or instance input.
    public static let vertex = Self(rawValue: 1 << 0)
    /// Supplies indices for indexed drawing.
    public static let index = Self(rawValue: 1 << 1)
    /// Supplies uniform shader data.
    public static let uniform = Self(rawValue: 1 << 2)
    /// Supplies general shader-readable or writable storage.
    public static let storage = Self(rawValue: 1 << 3)
    /// May be the source of a GPU copy.
    public static let copySource = Self(rawValue: 1 << 4)
    /// May be the destination of a GPU copy.
    public static let copyDestination = Self(rawValue: 1 << 5)
}
