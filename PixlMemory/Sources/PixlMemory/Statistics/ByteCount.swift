import Swift

/// A nonnegative quantity of bytes.
public struct ByteCount: Hashable, Comparable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func bytes(_ count: Int) -> Self {
        precondition(count >= 0, "Byte count must be nonnegative")
        return Self(rawValue: UInt64(count))
    }

    /// Creates a decimal kilobyte quantity where one kilobyte is 1,000 bytes.
    public static func kilobytes(_ count: Int) -> Self {
        multiplied(count, by: 1_000, unit: "Kilobyte")
    }

    /// Creates a decimal megabyte quantity where one megabyte is 1,000,000 bytes.
    public static func megabytes(_ count: Int) -> Self {
        multiplied(count, by: 1_000_000, unit: "Megabyte")
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        let (value, overflow) = lhs.rawValue.addingReportingOverflow(rhs.rawValue)
        precondition(!overflow, "Byte count overflow")
        return Self(rawValue: value)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        precondition(lhs >= rhs, "Byte count underflow")
        return Self(rawValue: lhs.rawValue - rhs.rawValue)
    }

    private static func multiplied(
        _ count: Int,
        by multiplier: UInt64,
        unit: StaticString
    ) -> Self {
        precondition(count >= 0, "\(unit) count must be nonnegative")
        let (value, overflow) = UInt64(count).multipliedReportingOverflow(
            by: multiplier
        )
        precondition(!overflow, "\(unit) count overflow")
        return Self(rawValue: value)
    }
}
