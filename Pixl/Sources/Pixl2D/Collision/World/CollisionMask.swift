/// Set of target layers whose colliders report contact to a source collider.
///
/// Filtering is intentionally one-way: a source reports contact when its mask
/// contains the target's layer. The target does not also need to opt in.
public struct CollisionMask: OptionSet, Hashable, Sendable {
    public let rawValue: UInt64

    /// Creates a mask from its raw layer bits.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Creates a mask containing one layer.
    public init(_ layer: CollisionLayer) {
        rawValue = Self.bit(for: layer)
    }

    /// Creates a mask containing the supplied layers.
    public init(_ layers: CollisionLayer...) {
        var value: UInt64 = 0
        for layer in layers {
            value |= Self.bit(for: layer)
        }
        rawValue = value
    }

    /// A mask containing no layers.
    public static let none: Self = []
    /// A mask containing every representable layer.
    public static let all = Self(rawValue: .max)

    @inline(__always)
    package func contains(layerBit: UInt64) -> Bool {
        rawValue & layerBit != 0
    }

    @inline(__always)
    package static func bit(for layer: CollisionLayer) -> UInt64 {
        guard layer.rawValue < UInt64.bitWidth else { return 0 }
        return UInt64(1) << UInt64(layer.rawValue)
    }
}
