import Swift

/// Stable game-defined sprite ordering. Lower layers render first.
public struct RenderLayer:
    RawRepresentable,
    ExpressibleByIntegerLiteral,
    Comparable,
    Hashable,
    Sendable
{
    public var rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        rawValue = value
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension RenderLayer {
    static func + (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue + rhs)
    }

    static func - (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue - rhs)
    }
}
