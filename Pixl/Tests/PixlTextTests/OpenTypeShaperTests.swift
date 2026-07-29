import Testing
@testable import PixlText

@Suite("OpenType shaping")
struct OpenTypeShaperTests {
    @Test("Single substitution preserves its source cluster")
    func singleSubstitution() {
        var glyphs = [glyph(12, sourceRange: 3..<4)]
        OpenTypeShaper.apply(
            substitutions([
                .single(input: 12, output: 40)
            ]),
            to: &glyphs
        )

        #expect(glyphs.map(\.id.rawValue) == [40])
        #expect(glyphs.map(\.sourceRange) == [3..<4])
        #expect(glyphs[0].lookupIndex == 2)
    }

    @Test("Ligature substitution merges glyphs and source ranges")
    func ligatureSubstitution() {
        var glyphs = [
            glyph(12, sourceRange: 2..<3),
            glyph(13, sourceRange: 3..<4)
        ]
        OpenTypeShaper.apply(
            substitutions([
                .ligature(components: [12, 13], output: 99)
            ]),
            to: &glyphs
        )

        #expect(glyphs.map(\.id.rawValue) == [99])
        #expect(glyphs.map(\.sourceRange) == [2..<4])
        #expect(glyphs[0].feature == 0x6C69_6761)
    }

    private func glyph(_ id: UInt16, sourceRange: Range<Int>) -> ShapingGlyph {
        .init(id: .init(rawValue: id), sourceRange: sourceRange, lookupIndex: nil, feature: nil)
    }

    private func substitutions(
        _ values: [SFNT.GlyphSubstitution.Substitution]
    ) -> SFNT.GlyphSubstitution {
        .init(lookups: [
            .init(index: 2, feature: 0x6C69_6761, substitutions: values)
        ])
    }
}
