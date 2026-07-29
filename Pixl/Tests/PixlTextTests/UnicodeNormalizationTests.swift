import Testing
@testable import PixlText

@Suite("Unicode normalization")
struct UnicodeNormalizationTests {
    @Test("Canonical equivalents normalize to the same NFC scalars")
    func canonicalEquivalence() {
        #expect(normalized("é") == normalized("e\u{301}"))
        #expect(normalized("e\u{301}").map(\.value) == [0xE9])
    }

    @Test("Combining marks are canonically ordered before composition")
    func canonicalOrdering() {
        #expect(normalized("a\u{315}\u{300}").map(\.value) == [0xE0, 0x315])
    }

    @Test("Hangul uses algorithmic decomposition and composition")
    func hangul() {
        #expect(normalized("\u{1100}\u{1161}\u{11A8}").map(\.value) == [0xAC01])
    }

    private func normalized(_ text: String) -> [Unicode.Scalar] {
        var buffer = UnicodeNormalizationBuffer()
        UnicodeNormalization.normalizeNFC(text.unicodeScalars, using: &buffer)
        return buffer.normalized
    }
}
