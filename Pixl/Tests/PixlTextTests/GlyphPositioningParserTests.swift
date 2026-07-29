import Testing
@testable import PixlText

@Suite("GPOS parser hardening")
struct GlyphPositioningParserTests {
    @Test("Nested extension lookup is rejected")
    func nestedExtension() {
        let bytes = tableWithLookup(type: 9, subtable: [
            0x00, 0x01, // extension format
            0x00, 0x09, // invalid nested extension type
            0x00, 0x00, 0x00, 0x00 // invalid zero offset
        ])

        #expect(throws: SFNT.RegistrationError.malformedRequiredTable) {
            try parse(bytes)
        }
    }

    @Test("Reversed class ranges are rejected")
    func reversedClassRange() {
        var subtable: [UInt8] = []
        append(2, to: &subtable)  // PairPos format 2
        append(16, to: &subtable) // coverage
        append(4, to: &subtable)  // value format 1: xAdvance
        append(0, to: &subtable)  // value format 2
        append(22, to: &subtable) // class definition 1
        append(32, to: &subtable) // class definition 2
        append(2, to: &subtable)  // class 1 count
        append(2, to: &subtable)  // class 2 count

        append(1, to: &subtable)  // coverage format 1
        append(1, to: &subtable)
        append(10, to: &subtable)

        append(2, to: &subtable)  // class definition format 2
        append(1, to: &subtable)
        append(20, to: &subtable) // reversed range
        append(10, to: &subtable)
        append(1, to: &subtable)

        append(1, to: &subtable)  // empty class definition format 1
        append(0, to: &subtable)
        append(0, to: &subtable)

        for _ in 0..<4 { append(0, to: &subtable) }

        let bytes = tableWithLookup(type: 2, subtable: subtable)
        #expect(throws: SFNT.RegistrationError.malformedRequiredTable) {
            try parse(bytes)
        }
    }

    @Test("Every truncated prefix fails without trapping")
    func truncation() {
        let complete = tableWithLookup(type: 9, subtable: [
            0x00, 0x01,
            0x00, 0x02,
            0x00, 0x00, 0x00, 0x08,
            0x00, 0x01, 0x00, 0x00, 0x00, 0x00
        ])

        for count in 0..<complete.count {
            let bytes = Array(complete.prefix(count))
            #expect(throws: (any Error).self) {
                try parse(bytes)
            }
        }
    }

    private func parse(_ bytes: [UInt8]) throws -> SFNT.GlyphPositioning {
        try SFNT.GlyphPositioning.parse(
            table: .init(offset: 0, length: bytes.count),
            bytes: bytes
        )
    }

    private func tableWithLookup(type: UInt16, subtable: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = []
        append32(0x0001_0000, to: &bytes)
        append(10, to: &bytes) // script list
        append(12, to: &bytes) // feature list
        append(14, to: &bytes) // lookup list
        append(0, to: &bytes)  // empty script list
        append(0, to: &bytes)  // empty feature list
        append(1, to: &bytes)  // lookup count
        append(4, to: &bytes)  // lookup offset
        append(type, to: &bytes)
        append(0, to: &bytes)  // lookup flags
        append(1, to: &bytes)  // subtable count
        append(8, to: &bytes)  // subtable offset
        bytes.append(contentsOf: subtable)
        return bytes
    }

    private func append(_ value: UInt16, to bytes: inout [UInt8]) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }

    private func append32(_ value: UInt32, to bytes: inout [UInt8]) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 24))
        bytes.append(UInt8(truncatingIfNeeded: value >> 16))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }
}
