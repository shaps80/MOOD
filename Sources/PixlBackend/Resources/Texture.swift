import Swift

public struct Texture: Hashable, Sendable {
    package let id: ResourceID
    public let descriptor: TextureDescriptor

    package init(
        id: ResourceID,
        descriptor: TextureDescriptor
    ) {
        self.id = id
        self.descriptor = descriptor
    }
}

public struct TextureDescriptor: Hashable, Sendable {
    public var size: TextureSize
    public var format: PixelFormat
    public var usage: TextureUsage
    public var sampleCount: Int

    public init(
        size: TextureSize,
        format: PixelFormat,
        usage: TextureUsage,
        sampleCount: Int = 1
    ) {
        self.size = size
        self.format = format
        self.usage = usage
        self.sampleCount = sampleCount
    }
}

public struct TextureSize: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var depthOrArrayLayers: Int

    public init(
        width: Int,
        height: Int,
        depthOrArrayLayers: Int = 1
    ) {
        self.width = width
        self.height = height
        self.depthOrArrayLayers = depthOrArrayLayers
    }
}

public enum PixelFormat: Hashable, Sendable {
    case rgba8Unorm
    case bgra8Unorm
    case depth32Float
}

public struct TextureUsage: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let sampled = TextureUsage(rawValue: 1 << 0)
    public static let renderAttachment = TextureUsage(rawValue: 1 << 1)
    public static let storage = TextureUsage(rawValue: 1 << 2)
    public static let copySource = TextureUsage(rawValue: 1 << 3)
    public static let copyDestination = TextureUsage(rawValue: 1 << 4)
}
