/// Discrete actions produced while advancing a platformer controller once.
public struct PlatformerEvents: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    /// Creates events from their packed action bits.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// A normal or additional jump began.
    public static let jumped = Self(rawValue: 1 << 0)
    /// A jump began after the initial jump allowance was consumed.
    public static let multiJumped = Self(rawValue: 1 << 1)
}
