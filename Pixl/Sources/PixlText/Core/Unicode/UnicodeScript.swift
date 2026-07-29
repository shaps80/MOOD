struct UnicodeScript: Hashable, Sendable {
    struct RangeEntry {
        let lower: UInt32
        let upper: UInt32
        let tag: UInt32
    }

    static let common = Self(tag: 0x7A79_7979) // Zyyy
    static let inherited = Self(tag: 0x7A69_6E68) // Zinh
    static let unknown = Self(tag: 0x7A7A_7A7A) // Zzzz

    let tag: UInt32

    static func script(for scalar: Unicode.Scalar) -> Self {
        var lower = 0
        var upper = ranges.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if ranges[middle].upper < scalar.value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < ranges.count,
              ranges[lower].lower <= scalar.value
        else {
            return .unknown
        }
        return .init(tag: ranges[lower].tag)
    }

    var isStrong: Bool {
        self != .common && self != .inherited && self != .unknown
    }
}
