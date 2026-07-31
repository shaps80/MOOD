import Testing
@testable import PixlText

@Suite("OpenType shaping")
struct OpenTypeShaperTests {
    @Test("Single substitution preserves its source cluster")
    func singleSubstitution() {
        var workspace = workspace([glyph(12, sourceRange: 3..<4)])
        let plan = substitutions([
                .single(input: 12, output: 40)
            ]).shapingPlan(script: 0x6C61_746E)
        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [40])
        #expect(sourceRanges(workspace.glyphs) == [3..<4])
        #expect(workspace.glyphs[0].lookupIndex == 0)
    }

    @Test("A lookup is not applied to a different script")
    func scriptSelection() {
        var workspace = workspace([glyph(12, sourceRange: 0..<1)])
        let plan = substitutions([.single(input: 12, output: 40)])
            .shapingPlan(script: 0x6172_6162) // arab
        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [12])
        #expect(workspace.glyphs[0].lookupIndex == nil)
    }

    @Test("Ligature substitution merges glyphs and source ranges")
    func ligatureSubstitution() {
        var workspace = workspace([
            glyph(12, sourceRange: 2..<3),
            glyph(13, sourceRange: 3..<4)
        ])
        let plan = substitutions([
                .ligature(components: [12, 13], output: 99)
            ]).shapingPlan(script: 0x6C61_746E)
        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [99])
        #expect(sourceRanges(workspace.glyphs) == [2..<4])
        #expect(workspace.glyphs[0].feature == 0x6C69_6761)
    }

    @Test("Multiple substitution expands and can delete glyphs")
    func multipleSubstitution() {
        var workspace = workspace([
            glyph(10, sourceRange: 0..<1),
            glyph(11, sourceRange: 1..<2)
        ])
        let plan = substitutions([
            .multiple(input: 10, outputs: [20, 21]),
            .multiple(input: 11, outputs: [])
        ]).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [20, 21])
        #expect(sourceRanges(workspace.glyphs) == [0..<1, 0..<1])
    }

    @Test("Alternate substitution deterministically selects the first alternate")
    func alternateSubstitution() {
        var workspace = workspace([glyph(10, sourceRange: 0..<1)])
        let plan = substitutions([
            .alternate(input: 10, outputs: [30, 31])
        ]).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [30])
    }

    @Test("Chained context invokes a nested lookup")
    func chainedContext() {
        let context = SFNT.OpenTypeLayout.ContextRule(
            firstCoverage: nil,
            backtrack: [.glyph(1)],
            input: [.glyph(2)],
            lookahead: [.glyph(3)],
            actions: [.init(sequenceIndex: 0, lookupIndex: 1)]
        )
        var workspace = workspace([
            glyph(1, sourceRange: 0..<1),
            glyph(2, sourceRange: 1..<2),
            glyph(3, sourceRange: 2..<3)
        ])
        let plan = substitutions(
            lookups: [
                .init(index: 0, substitutions: [.context(context)]),
                .init(index: 1, substitutions: [.single(input: 2, output: 9)])
            ],
            activeLookupIndices: [0]
        ).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [1, 9, 3])
    }

    @Test("Context action indices address the sequence after preceding actions")
    func contextActionOrder() {
        let context = SFNT.OpenTypeLayout.ContextRule(
            firstCoverage: nil,
            backtrack: [],
            input: [.glyph(1), .glyph(2), .glyph(3)],
            lookahead: [],
            actions: [
                .init(sequenceIndex: 1, lookupIndex: 1),
                .init(sequenceIndex: 0, lookupIndex: 2)
            ]
        )
        var workspace = workspace([
            glyph(1, sourceRange: 0..<1),
            glyph(2, sourceRange: 1..<2),
            glyph(3, sourceRange: 2..<3)
        ])
        let plan = substitutions(
            lookups: [
                .init(index: 0, substitutions: [.context(context)]),
                .init(index: 1, substitutions: [
                    .ligature(components: [2, 3], output: 9)
                ]),
                .init(index: 2, substitutions: [.single(input: 1, output: 8)])
            ],
            activeLookupIndices: [0]
        ).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [8, 9])
    }

    @Test("Ignored marks survive ligature substitution with component metadata")
    func ligatureIgnoresMarks() {
        let flags = SFNT.OpenTypeLayout.LookupFlags(
            rawValue: 0x0008,
            markFilteringSet: nil
        )
        let definition = SFNT.GlyphDefinition(
            glyphClasses: .init(ranges: [
                .init(glyphs: 10...10, value: 1),
                .init(glyphs: 20...20, value: 1),
                .init(glyphs: 30...30, value: 3)
            ]),
            markAttachmentClasses: nil,
            markGlyphSets: []
        )
        var workspace = workspace([
            glyph(10, sourceRange: 0..<1),
            glyph(30, sourceRange: 1..<2),
            glyph(20, sourceRange: 2..<3)
        ])
        let plan = substitutions(
            lookups: [
                .init(
                    index: 0,
                    flags: flags,
                    substitutions: [.ligature(components: [10, 20], output: 99)]
                )
            ],
            activeLookupIndices: [0]
        ).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(
            plan,
            glyphDefinition: definition,
            workspace: &workspace
        )

        #expect(ids(workspace.glyphs) == [99, 30])
        #expect(workspace.glyphs[0].ligatureComponentCount == 2)
        #expect(workspace.glyphs[1].ligatureComponent == 1)
    }

    @Test("Mark filtering lookup flags require a valid GDEF mark set")
    func markFilteringValidation() {
        let flags = SFNT.OpenTypeLayout.LookupFlags(
            rawValue: 0x0010,
            markFilteringSet: 1
        )
        let definition = SFNT.GlyphDefinition(
            glyphClasses: nil,
            markAttachmentClasses: nil,
            markGlyphSets: [.init(glyphs: [30])]
        )

        #expect(throws: SFNT.RegistrationError.malformedRequiredTable) {
            try SFNT.GlyphDefinition.validate(flags: flags, against: definition)
        }
        #expect(throws: SFNT.RegistrationError.malformedRequiredTable) {
            try SFNT.GlyphDefinition.validate(flags: flags, against: nil)
        }
    }

    @Test("Reverse chained substitution scans from the end")
    func reverseSubstitution() {
        let rule = SFNT.GlyphSubstitution.ReverseRule(
            input: .init(glyphs: [2]),
            backtrack: [.init(glyphs: [1])],
            lookahead: [.init(glyphs: [3])],
            outputs: [8]
        )
        var workspace = workspace([
            glyph(1, sourceRange: 0..<1),
            glyph(2, sourceRange: 1..<2),
            glyph(3, sourceRange: 2..<3)
        ])
        let plan = substitutions([.reverse(rule)]).shapingPlan(script: 0x6C61_746E)

        OpenTypeShaper.apply(plan, workspace: &workspace)

        #expect(ids(workspace.glyphs) == [1, 8, 3])
    }

    private func glyph(_ id: UInt16, sourceRange: Range<Int>) -> ShapingGlyph {
        .init(id: .init(rawValue: id), sourceRange: sourceRange, lookupIndex: nil, feature: nil)
    }

    private func workspace(_ glyphs: [ShapingGlyph]) -> ShapingScratch {
        var result = ShapingScratch(minimumGlyphCapacity: glyphs.count)
        for glyph in glyphs { result.glyphs.append(glyph) }
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
        substitutions(
            lookups: [.init(index: 0, substitutions: values)],
            activeLookupIndices: [0]
        )
    }

    private func substitutions(
        lookups: [SFNT.GlyphSubstitution.Lookup],
        activeLookupIndices: [Int]
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
                .init(tag: 0x6C69_6761, lookupIndices: activeLookupIndices)
            ],
            lookups: lookups
        )
    }
}
