import Swift

package struct Half {
    package let bitPattern: UInt16

    package init(_ value: Float) {
        let bits = value.bitPattern
        let sign = UInt16(truncatingIfNeeded: bits >> 16) & 0x8000
        let exponent = Int((bits >> 23) & 0xff) - 127 + 15
        let significand = bits & 0x7fffff

        if exponent >= 31 {
            if significand == 0 {
                bitPattern = sign | 0x7c00
            } else {
                let payload = UInt16(truncatingIfNeeded: significand >> 13)
                bitPattern = sign | 0x7c00 | payload | 1
            }
            return
        }

        if exponent <= 0 {
            guard exponent >= -10 else {
                bitPattern = sign
                return
            }

            let value = significand | 0x800000
            let shift = UInt32(14 - exponent)
            let truncated = value >> shift
            let remainderMask = (UInt32(1) << shift) - 1
            let remainder = value & remainderMask
            let halfway = UInt32(1) << (shift - 1)
            let rounded = truncated + (
                remainder > halfway ||
                    (remainder == halfway && truncated & 1 == 1)
                    ? 1
                    : 0
            )
            bitPattern = sign | UInt16(truncatingIfNeeded: rounded)
            return
        }

        var encoded = UInt32(exponent) << 10 | significand >> 13
        let remainder = significand & 0x1fff
        if remainder > 0x1000 || (remainder == 0x1000 && encoded & 1 == 1) {
            encoded += 1
        }

        bitPattern = sign | UInt16(truncatingIfNeeded: encoded)
    }
}
