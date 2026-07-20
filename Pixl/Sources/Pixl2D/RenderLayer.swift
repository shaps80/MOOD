import Swift

/// Stable game-defined sprite ordering. Lower layers render first.
public struct RenderLayer:
    RawRepresentable,
    ExpressibleByIntegerLiteral,
    Comparable,
    Hashable,
    Sendable
{
    public var rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension RenderLayer {
    static func + (lhs: Self, rhs: UInt32) -> Self {
        .init(lhs.rawValue + rhs)
    }

    static func - (lhs: Self, rhs: UInt32) -> Self {
        .init(lhs.rawValue - rhs)
    }
}
