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
        .init(
            scripts: [
                .init(
                    tag: latin,
                    defaultLanguage: .init(requiredFeatureIndex: nil, featureIndices: [0]),
                    languages: []
                )
            ],
            features: [.init(tag: kern, lookupIndices: [0])],
            lookups: [.init(index: 0, pairs: [pair])]
        )
    }
}
