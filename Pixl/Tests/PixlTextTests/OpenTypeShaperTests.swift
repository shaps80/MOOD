import Testing
@testable import PixlText

@Suite("OpenType shaping")
struct OpenTypeShaperTests {
    @Test("Single substitution preserves its source cluster")
    func singleSubstitution() {
        var glyphs = buffer([glyph(12, sourceRange: 3..<4)])
        let plan = substitutions([
                .single(input: 12, output: 40)
            ]).shapingPlan(script: 0x6C61_746E)
        OpenTypeShaper.apply(plan, to: &glyphs)

        #expect(ids(glyphs) == [40])
        #expect(sourceRanges(glyphs) == [3..<4])
        #expect(glyphs[0].lookupIndex == 0)
    }

    @Test("A lookup is not applied to a different script")
    func scriptSelection() {
        var glyphs = buffer([glyph(12, sourceRange: 0..<1)])
        let plan = substitutions([.single(input: 12, output: 40)])
            .shapingPlan(script: 0x6172_6162) // arab
        OpenTypeShaper.apply(plan, to: &glyphs)

        #expect(ids(glyphs) == [12])
        #expect(glyphs[0].lookupIndex == nil)
    }

    @Test("Ligature substitution merges glyphs and source ranges")
    func ligatureSubstitution() {
        var glyphs = buffer([
            glyph(12, sourceRange: 2..<3),
            glyph(13, sourceRange: 3..<4)
        ])
        let plan = substitutions([
                .ligature(components: [12, 13], output: 99)
            ]).shapingPlan(script: 0x6C61_746E)
        OpenTypeShaper.apply(plan, to: &glyphs)

        #expect(ids(glyphs) == [99])
        #expect(sourceRanges(glyphs) == [2..<4])
        #expect(glyphs[0].feature == 0x6C69_6761)
    }

    private func glyph(_ id: UInt16, sourceRange: Range<Int>) -> ShapingGlyph {
        .init(id: .init(rawValue: id), sourceRange: sourceRange, lookupIndex: nil, feature: nil)
    }

    private func buffer(_ glyphs: [ShapingGlyph]) -> GlyphBuffer {
        var result = GlyphBuffer(minimumCapacity: glyphs.count)
        for glyph in glyphs { result.append(glyph) }
        return result
    }

    private func ids(_ glyphs: borrowing GlyphBuffer) -> [UInt16] {
        (0..<glyphs.count).map { glyphs[$0].id.rawValue }
    }

    private func sourceRanges(_ glyphs: borrowing GlyphBuffer) -> [Range<Int>] {
        (0..<glyphs.count).map { glyphs[$0].sourceRange }
    }

    private func substitutions(
        _ values: [SFNT.GlyphSubstitution.Substitution]
    ) -> SFNT.GlyphSubstitution {
        .init(
            scripts: [
                .init(
                    tag: 0x6C61_746E,
                    defaultLanguage: .init(requiredFeatureIndex: nil, featureIndices: [0]),
                    languages: []
                )
            ],
            features: [
                .init(tag: 0x6C69_6761, lookupIndices: [0])
            ],
            lookups: [
                .init(index: 0, substitutions: values)
            ]
        )
    }
}
