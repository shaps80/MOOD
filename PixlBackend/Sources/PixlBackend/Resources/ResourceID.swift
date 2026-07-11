import Swift

package struct ResourceID: Hashable, Sendable {
    package let rawValue: UInt64

    package var index: UInt32 {
        UInt32(truncatingIfNeeded: rawValue)
    }

    package var generation: UInt32 {
        UInt32(truncatingIfNeeded: rawValue >> 32)
    }

    package init(index: UInt32, generation: UInt32) {
        rawValue = UInt64(index) | UInt64(generation) << 32
    }
}
