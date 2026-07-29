enum OpenTypeShaper {
    static func apply(
        _ plan: borrowing OpenTypeShapingPlan,
        to glyphs: inout GlyphBuffer
    ) {
        for lookup in plan.lookups {
            switch lookup.kind {
            case .single:
                applySingle(lookup, plan: plan, to: &glyphs)
            case .ligature:
                applyLigatures(lookup, plan: plan, to: &glyphs)
            }
        }
    }

    private static func applySingle(
        _ lookup: OpenTypeShapingPlan.Lookup,
        plan: borrowing OpenTypeShapingPlan,
        to glyphs: inout GlyphBuffer
    ) {
        for index in 0..<glyphs.count {
            let id = glyphs[index].id.rawValue
            guard let rule = singleRule(for: id, in: lookup.rules, plan: plan) else {
                continue
            }
            glyphs[index].id = .init(rawValue: rule.output)
            glyphs[index].lookupIndex = lookup.sourceIndex
            glyphs[index].feature = lookup.feature
        }
    }

    private static func applyLigatures(
        _ lookup: OpenTypeShapingPlan.Lookup,
        plan: borrowing OpenTypeShapingPlan,
        to glyphs: inout GlyphBuffer
    ) {
        var read = 0
        var write = 0
        let originalCount = glyphs.count

        while read < originalCount {
            let id = glyphs[read].id.rawValue
            if let rule = matchingLigature(
                first: id,
                at: read,
                glyphCount: originalCount,
                rules: lookup.rules,
                plan: plan,
                glyphs: glyphs
            ) {
                let componentCount = rule.components.count
                let sourceRange = Range(
                    uncheckedBounds: (
                        glyphs[read].sourceRange.lowerBound,
                        glyphs[read + componentCount - 1].sourceRange.upperBound
                    )
                )
                glyphs[write] = .init(
                    id: .init(rawValue: rule.output),
                    sourceRange: sourceRange,
                    lookupIndex: lookup.sourceIndex,
                    feature: lookup.feature
                )
                read += componentCount
            } else {
                if write != read {
                    glyphs[write] = glyphs[read]
                }
                read += 1
            }
            write += 1
        }

        if write < originalCount {
            glyphs.removeLast(originalCount - write)
        }
    }

    private static func singleRule(
        for glyph: UInt16,
        in range: Range<Int>,
        plan: borrowing OpenTypeShapingPlan
    ) -> OpenTypeShapingPlan.SingleRule? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let rule = plan.singleRules[middle]
            if rule.input < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < range.upperBound, plan.singleRules[lower].input == glyph else { return nil }
        return plan.singleRules[lower]
    }

    private static func matchingLigature(
        first glyph: UInt16,
        at glyphIndex: Int,
        glyphCount: Int,
        rules: Range<Int>,
        plan: borrowing OpenTypeShapingPlan,
        glyphs: borrowing GlyphBuffer
    ) -> OpenTypeShapingPlan.LigatureRule? {
        var lower = rules.lowerBound
        var upper = rules.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if plan.ligatureRules[middle].first < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        var index = lower
        while index < rules.upperBound {
            let rule = plan.ligatureRules[index]
            guard rule.first == glyph else { break }
            let count = rule.components.count
            if glyphIndex + count <= glyphCount {
                var matches = true
                for componentIndex in 0..<count where
                    glyphs[glyphIndex + componentIndex].id.rawValue
                        != plan.ligatureComponents[rule.components.lowerBound + componentIndex] {
                    matches = false
                    break
                }
                if matches { return rule }
            }
            index += 1
        }
        return nil
    }
}
