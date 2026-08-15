import Swift

/// Philox4x32-10 from the Random123 family of counter-based generators.
struct Philox4x32 {
    struct Counter: Equatable, Sendable {
        var x0: UInt32
        var x1: UInt32
        var x2: UInt32
        var x3: UInt32

        @inline(__always)
        init(_ x0: UInt32, _ x1: UInt32, _ x2: UInt32, _ x3: UInt32) {
            self.x0 = x0
            self.x1 = x1
            self.x2 = x2
            self.x3 = x3
        }
    }

    struct Key: Sendable {
        var x0: UInt32
        var x1: UInt32

        @inline(__always)
        init(_ x0: UInt32, _ x1: UInt32) {
            self.x0 = x0
            self.x1 = x1
        }
    }

    private static let multiplier0: UInt32 = 0xD2511F53
    private static let multiplier1: UInt32 = 0xCD9E8D57
    private static let keyIncrement0: UInt32 = 0x9E3779B9
    private static let keyIncrement1: UInt32 = 0xBB67AE85

    @inline(__always)
    static func generate(counter: Counter, key: Key) -> Counter {
        var counter = round(counter, key: key)
        var key = key

        for _ in 1..<10 {
            key.x0 &+= keyIncrement0
            key.x1 &+= keyIncrement1
            counter = round(counter, key: key)
        }

        return counter
    }

    @inline(__always)
    private static func round(_ counter: Counter, key: Key) -> Counter {
        let product0 = UInt64(multiplier0) * UInt64(counter.x0)
        let product1 = UInt64(multiplier1) * UInt64(counter.x2)

        return Counter(
            UInt32(product1 >> 32) ^ counter.x1 ^ key.x0,
            UInt32(truncatingIfNeeded: product1),
            UInt32(product0 >> 32) ^ counter.x3 ^ key.x1,
            UInt32(truncatingIfNeeded: product0)
        )
    }
}
