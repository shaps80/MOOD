enum UnicodeLineBreakProperty: UInt8, Sendable {
    case ai, ak, al, ap, `as`, b2, ba, bb, bk, cb, cj, cl, cm, cp, cr
    case eb, em, ex, gl, h2, h3, hl, hy, id, `in`, `is`, jl, jt, jv, lf
    case nl, ns, nu, op, po, pr, qu, ri, sa, sg, sp, sy, vf, vi, wj, xx
    case zw, zwj

    struct Attributes: Sendable {
        let lineBreak: UnicodeLineBreakProperty
        let isEastAsian: Bool
        let isInitialPunctuation: Bool
        let isFinalPunctuation: Bool
        let isMark: Bool
        let isExtendedPictographic: Bool
    }

    static func attributes(for scalar: Unicode.Scalar) -> Attributes {
        let page = Int(scalar.value >> 8)
        let value = UInt32(scalar.value & 0xFF)
        var lower = Int(pageStarts[page])
        var upper = Int(pageStarts[page + 1])
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if entries[middle] & 0xFF < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let packed = entries[lower] >> 8
        return .init(
            lineBreak: .init(rawValue: UInt8(packed & 0x3F))!,
            isEastAsian: packed & (1 << 6) != 0,
            isInitialPunctuation: packed & (1 << 7) != 0,
            isFinalPunctuation: packed & (1 << 8) != 0,
            isMark: packed & (1 << 9) != 0,
            isExtendedPictographic: packed & (1 << 10) != 0
        )
    }
}
