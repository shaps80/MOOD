import Swift

/// Stable game-defined sprite ordering. Lower layers render first.
public struct RenderLayer:
    RawRepresentable,
    ExpressibleByIntegerLiteral,
    Comparable,
    Hashable,
    Sendable
{
    /// Numeric ordering value. Lower values render first.
    public var rawValue: UInt32

    /// Creates a render layer from its numeric ordering value.
    /// - Parameter rawValue: Layer value; lower values render first.
    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Creates a render layer satisfying `RawRepresentable`.
    /// - Parameter rawValue: Layer value; lower values render first.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Creates a render layer from an integer literal.
    /// - Parameter value: Layer value; lower values render first.
    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    /// Compares layers by their numeric ordering values.
    /// - Parameters:
    ///   - lhs: Layer on the left side of the comparison.
    ///   - rhs: Layer on the right side of the comparison.
    /// - Returns: `true` when `lhs` renders before `rhs`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension RenderLayer {
    /// Returns a layer offset upward by an unsigned amount.
    /// - Parameters:
    ///   - lhs: Base layer.
    ///   - rhs: Amount added to its raw value.
    /// - Returns: The offset layer.
    static func + (lhs: Self, rhs: UInt32) -> Self {
        .init(lhs.rawValue + rhs)
    }

    /// Returns a layer offset downward by an unsigned amount.
    /// - Parameters:
    ///   - lhs: Base layer.
    ///   - rhs: Amount subtracted from its raw value.
    /// - Returns: The offset layer.
    static func - (lhs: Self, rhs: UInt32) -> Self {
        .init(lhs.rawValue - rhs)
    }
}
