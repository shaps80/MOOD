/// Game-defined identity used by collision filtering.
///
/// Values `0...63` map to the corresponding bit in ``CollisionMask``. Larger
/// values are valid identities but deliberately match no mask.
public struct CollisionLayer:
    RawRepresentable,
    ExpressibleByIntegerLiteral,
    Hashable,
    Sendable
{
    public let rawValue: UInt8

    /// Creates a layer from its game-defined numeric identity.
    public init(_ rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Creates a layer satisfying `RawRepresentable`.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Creates a layer from an integer literal.
    public init(integerLiteral value: UInt8) {
        rawValue = value
    }
}
