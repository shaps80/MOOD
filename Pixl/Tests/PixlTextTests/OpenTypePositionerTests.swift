import Testing
@testable import PixlText

@Suite("OpenType positioning")
struct OpenTypePositionerTests {
    @Test("Glyph pair adjustment changes advances and placements")
    func glyphPairs() {
        var glyphs = buffer([glyph(10), glyph(20)])
        let positioning = makePositioning(.glyphs([
            .init(
                first: 10,
                second: 20,
                firstAdjustment: .init(xAdvance: -80),
                secondAdjustment: .init(xPlacement: 12, yPlacement: 3)
            )
        ]))

        OpenTypePositioner.apply(
            positioning.positioningPlan(script: latin),
            to: &glyphs
        )

        #expect(glyphs[0].xAdvance == -80)
        #expect(glyphs[1].xPlacement == 12)
        #expect(glyphs[1].yPlacement == 3)
        #expect(glyphs[0].feature == kern)
    }

    @Test("Class pair adjustment supports default class zero")
    func classPairs() {
        var glyphs = buffer([glyph(10), glyph(99)])
        let zero = SFNT.GlyphPositioning.ValueAdjustment()
        let kerned = SFNT.GlyphPositioning.ValueAdjustment(xAdvance: -40)
        let table = SFNT.GlyphPositioning.ClassPairTable(
            coverage: [10],
            firstClasses: [.init(glyphs: 10...10, value: 1)],
            secondClasses: [.init(glyphs: 20...20, value: 1)],
            firstClassCount: 2,
            secondClassCount: 2,
            firstAdjustments: [zero, zero, kerned, zero],
            secondAdjustments: [zero, zero, zero, zero]
        )

        OpenTypePositioner.apply(
            makePositioning(.classes(table)).positioningPlan(script: latin),
            to: &glyphs
        )

        #expect(glyphs[0].xAdvance == -40)
    }

    @Test("Single positioning adjusts one glyph")
    func singlePositioning() {
        var glyphs = buffer([glyph(10)])
        let positioning = makePositioning([
            .init(index: 0, subtables: [.single([
                .init(glyph: 10, adjustment: .init(xPlacement: 7, yAdvance: 3))
            ])])
        ])

        OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)

        #expect(glyphs[0].xPlacement == 7)
        #expect(glyphs[0].yAdvance == 3)
    }

    @Test("Cursive positioning joins exit and entry anchors")
    func cursivePositioning() {
        var first = glyph(10)
        first.nominalXAdvance = 100
        var glyphs = buffer([first, glyph(20)])
        let positioning = makePositioning([
            .init(index: 0, subtables: [.cursive([
                .init(glyph: 10, entry: nil, exit: .init(x: 80, y: 20)),
                .init(glyph: 20, entry: .init(x: 0, y: 5), exit: nil)
            ])])
        ])

        OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)

        #expect(glyphs[0].xAdvance == -20)
        #expect(glyphs[1].yPlacement == 15)
    }

    @Test("Mark positioning attaches to a base anchor")
    func markToBase() {
        var base = glyph(10)
        base.nominalXAdvance = 100
        var glyphs = buffer([base, glyph(20)])
        let table = SFNT.GlyphPositioning.MarkToBaseTable(
            marks: [.init(glyph: 20, markClass: 0, anchor: .init(x: 5, y: 20))],
            bases: [.init(glyph: 10, anchors: [.init(x: 50, y: 100)])],
            classCount: 1
        )
        let positioning = makePositioning([
            .init(index: 0, subtables: [.markToBase(table)])
        ])

        OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)

        #expect(glyphs[1].xPlacement == -55)
        #expect(glyphs[1].yPlacement == 80)
    }

    @Test("Mark-to-ligature positioning uses preserved component metadata")
    func markToLigature() {
        var ligature = glyph(99)
        ligature.nominalXAdvance = 100
        ligature.ligatureComponentCount = 2
        var mark = glyph(30)
        mark.ligatureComponent = 1
        var glyphs = buffer([ligature, mark])
        let table = SFNT.GlyphPositioning.MarkToLigatureTable(
            marks: [.init(glyph: 30, markClass: 0, anchor: .init(x: 5, y: 20))],
            ligatures: [.init(glyph: 99, components: [
                [.init(x: 50, y: 100)],
                [.init(x: 80, y: 100)]
            ])],
            classCount: 1
        )
        let positioning = makePositioning([
            .init(index: 0, subtables: [.markToLigature(table)])
        ])

        OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)

        #expect(glyphs[1].xPlacement == -55)
        #expect(glyphs[1].yPlacement == 80)
    }

    @Test("Context positioning invokes a nested lookup")
    func contextPositioning() {
        let context = SFNT.OpenTypeLayout.ContextRule(
            firstCoverage: nil,
            backtrack: [.glyph(1)],
            input: [.glyph(2)],
            lookahead: [.glyph(3)],
            actions: [.init(sequenceIndex: 0, lookupIndex: 1)]
        )
        var glyphs = buffer([glyph(1), glyph(2), glyph(3)])
        let positioning = makePositioning(
            [
                .init(index: 0, subtables: [.context(context)]),
                .init(index: 1, subtables: [.single([
                    .init(glyph: 2, adjustment: .init(xAdvance: -12))
                ])])
            ],
            activeLookupIndices: [0]
        )

        OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)

        #expect(glyphs[1].xAdvance == -12)
    }

    private var latin: UInt32 { 0x6C61_746E }
    private var kern: UInt32 { 0x6B65_726E }

    private func glyph(_ id: UInt16) -> ShapingGlyph {
        .init(
            id: .init(rawValue: id),
            sourceRange: 0..<1,
            lookupIndex: nil,
            feature: nil
        )
    }

    private func buffer(_ values: [ShapingGlyph]) -> GlyphBuffer {
        var result = GlyphBuffer(minimumCapacity: values.count)
        for value in values { result.append(value) }
        return result
    }

    private func makePositioning(
        _ pair: SFNT.GlyphPositioning.PairSubtable
    ) -> SFNT.GlyphPositioning {
        makePositioning([.init(index: 0, pairs: [pair])])
    }

    private func makePositioning(
        _ lookups: [SFNT.GlyphPositioning.Lookup],
        activeLookupIndices: [Int] = [0]
    ) -> SFNT.GlyphPositioning {
        .init(
            scripts: [
                .init(
                    tag: latin,
                    defaultLanguage: .init(requiredFeatureIndex: nil, featureIndices: [0]),
                    languages: []
                )
            ],
            features: [.init(tag: kern, lookupIndices: activeLookupIndices)],
            lookups: lookups,
            featureVariations: nil
        )
    }
}
