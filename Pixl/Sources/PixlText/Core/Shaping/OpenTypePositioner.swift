enum OpenTypePositioner {
    static func apply(
        _ plan: borrowing OpenTypePositioningPlan,
        to glyphs: inout GlyphBuffer
    ) {
        guard glyphs.count > 1 else { return }
        for lookup in plan.lookups {
            for glyphIndex in 0..<(glyphs.count - 1) {
                for subtableIndex in lookup.subtables {
                    guard let pair = adjustment(
                        first: glyphs[glyphIndex].id.rawValue,
                        second: glyphs[glyphIndex + 1].id.rawValue,
                        subtable: plan.subtables[subtableIndex],
                        plan: plan
                    ) else { continue }
                    apply(pair.0, to: &glyphs[glyphIndex])
                    apply(pair.1, to: &glyphs[glyphIndex + 1])
                    glyphs[glyphIndex].lookupIndex = lookup.sourceIndex
                    glyphs[glyphIndex].feature = lookup.feature
                    break
                }
            }
        }
    }

    private static func adjustment(
        first: UInt16,
        second: UInt16,
        subtable: OpenTypePositioningPlan.Subtable,
        plan: borrowing OpenTypePositioningPlan
    ) -> (
        SFNT.GlyphPositioning.ValueAdjustment,
        SFNT.GlyphPositioning.ValueAdjustment
    )? {
        switch subtable {
        case .glyphPairs(let range):
            let key = UInt32(first) << 16 | UInt32(second)
            var lower = range.lowerBound
            var upper = range.upperBound
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if plan.pairRules[middle].key < key { lower = middle + 1 } else { upper = middle }
            }
            guard lower < range.upperBound, plan.pairRules[lower].key == key else { return nil }
            let rule = plan.pairRules[lower]
            return (rule.first, rule.second)

        case .classPairs(let index):
            let table = plan.classTables[index]
            guard contains(first, in: table.coverage) else { return nil }
            let firstClass = Int(classValue(for: first, in: table.firstClasses))
            let secondClass = Int(classValue(for: second, in: table.secondClasses))
            guard firstClass < table.firstClassCount, secondClass < table.secondClassCount else {
                return nil
            }
            let pairIndex = firstClass * table.secondClassCount + secondClass
            guard pairIndex < table.firstAdjustments.count,
                  pairIndex < table.secondAdjustments.count
            else { return nil }
            return (table.firstAdjustments[pairIndex], table.secondAdjustments[pairIndex])
        }
    }

    private static func apply(
        _ adjustment: SFNT.GlyphPositioning.ValueAdjustment,
        to glyph: inout ShapingGlyph
    ) {
        glyph.xPlacement += Int32(adjustment.xPlacement)
        glyph.yPlacement += Int32(adjustment.yPlacement)
        glyph.xAdvance += Int32(adjustment.xAdvance)
        glyph.yAdvance += Int32(adjustment.yAdvance)
    }

    private static func contains(_ glyph: UInt16, in sorted: [UInt16]) -> Bool {
        var lower = 0
        var upper = sorted.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if sorted[middle] < glyph { lower = middle + 1 } else { upper = middle }
        }
        return lower < sorted.count && sorted[lower] == glyph
    }

    private static func classValue(
        for glyph: UInt16,
        in ranges: [SFNT.GlyphPositioning.ClassRange]
    ) -> UInt16 {
        var lower = 0
        var upper = ranges.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if ranges[middle].glyphs.upperBound < glyph { lower = middle + 1 } else { upper = middle }
        }
        guard lower < ranges.count, ranges[lower].glyphs.contains(glyph) else { return 0 }
        return ranges[lower].value
    }
}
