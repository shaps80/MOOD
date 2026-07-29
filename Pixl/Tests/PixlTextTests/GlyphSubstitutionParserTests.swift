import Testing
@testable import PixlText

@Suite("GSUB parser hardening")
struct GlyphSubstitutionParserTests {
    @Test("Multiple substitution permits deletion")
    func multipleDeletion() throws {
        let substitution = try parse(tableWithLookup(type: 2, subtable: [
            0x00, 0x01, // multiple substitution format
            0x00, 0x08, // coverage offset
            0x00, 0x01, // sequence count
            0x00, 0x0E, // sequence offset
            0x00, 0x01, // coverage format
            0x00, 0x01, // coverage glyph count
            0x00, 0x0A, // input glyph
            0x00, 0x00  // zero outputs: delete input
        ]))

        guard case let .multiple(input, outputs) = substitution.lookups[0].substitutions[0]
        else {
            Issue.record("Expected multiple substitution")
            return
        }
        #expect(input == 10)
        #expect(outputs.isEmpty)
    }

    @Test("Every truncated prefix fails without trapping")
    func truncation() {
        let complete = tableWithLookup(type: 2, subtable: [
            0x00, 0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x0E,
            0x00, 0x01, 0x00, 0x01, 0x00, 0x0A, 0x00, 0x00
        ])

        for count in 0..<complete.count {
            #expect(throws: (any Error).self) {
                try parse(Array(complete.prefix(count)))
            }
        }
    }

    private func parse(_ bytes: [UInt8]) throws -> SFNT.GlyphSubstitution {
        try SFNT.GlyphSubstitution.parse(
            table: .init(offset: 0, length: bytes.count),
            bytes: bytes
        )
    }

    private func tableWithLookup(type: UInt16, subtable: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = []
        append32(0x0001_0000, to: &bytes)
        append(10, to: &bytes)
        append(12, to: &bytes)
        append(14, to: &bytes)
        append(0, to: &bytes)
        append(0, to: &bytes)
        append(1, to: &bytes)
        append(4, to: &bytes)
        append(type, to: &bytes)
        append(0, to: &bytes)
        append(1, to: &bytes)
        append(8, to: &bytes)
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
