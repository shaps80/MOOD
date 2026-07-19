import Swift

package struct RenderOrder: Comparable, Sendable {
    package let layer: Int
    package let ordinal: Int

    package static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.layer, lhs.ordinal) < (rhs.layer, rhs.ordinal)
    }
}

