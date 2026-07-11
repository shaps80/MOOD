import Swift

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
