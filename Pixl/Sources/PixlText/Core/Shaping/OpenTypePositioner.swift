enum OpenTypePositioner {
    private static let maximumContextDepth = 64

    static func apply(
        _ plan: borrowing OpenTypePositioningPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition? = nil,
        to glyphs: inout GlyphBuffer
    ) {
        for execution in plan.executions where plan.lookups.indices.contains(execution.lookupIndex) {
            let lookup = plan.lookups[execution.lookupIndex]
            var index = 0
            while index < glyphs.count {
                if isIgnored(glyphs[index], by: lookup.flags, definition: glyphDefinition) {
                    index += 1
                    continue
                }
                _ = applyLookupAt(
                    execution.lookupIndex,
                    at: index,
                    feature: execution.feature,
                    depth: 0,
                    plan: plan,
                    glyphDefinition: glyphDefinition,
                    glyphs: &glyphs
                )
                index += 1
            }
        }
    }

    private static func applyLookupAt(
        _ lookupIndex: Int,
        at glyphIndex: Int,
        feature: UInt32,
        depth: Int,
        plan: borrowing OpenTypePositioningPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        guard depth < maximumContextDepth,
              plan.lookups.indices.contains(lookupIndex),
              glyphs.count > glyphIndex
        else { return false }
        let lookup = plan.lookups[lookupIndex]
        guard !isIgnored(glyphs[glyphIndex], by: lookup.flags, definition: glyphDefinition) else {
            return false
        }

        for subtableIndex in lookup.subtables {
            switch plan.subtables[subtableIndex] {
            case .single(let rules):
                guard let rule = singleRule(
                    glyphs[glyphIndex].id.rawValue,
                    rules: rules,
                    plan: plan
                ) else { continue }
                apply(resolved(rule.adjustment, plan: plan), to: &glyphs[glyphIndex])
                mark(&glyphs[glyphIndex], lookup: lookup, feature: feature)
                return true

            case .glyphPairs, .classPairs:
                guard let secondIndex = nextIncluded(
                    after: glyphIndex,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ), let pair = pairAdjustment(
                    first: glyphs[glyphIndex].id.rawValue,
                    second: glyphs[secondIndex].id.rawValue,
                    subtable: plan.subtables[subtableIndex],
                    plan: plan
                ) else { continue }
                let firstAdjustment = resolved(pair.0, plan: plan)
                let secondAdjustment = resolved(pair.1, plan: plan)
                apply(firstAdjustment, to: &glyphs[glyphIndex])
                apply(secondAdjustment, to: &glyphs[secondIndex])
                mark(&glyphs[glyphIndex], lookup: lookup, feature: feature)
                if !secondAdjustment.isZero {
                    mark(&glyphs[secondIndex], lookup: lookup, feature: feature)
                }
                return true

            case .cursive(let rules):
                guard let secondIndex = nextIncluded(
                    after: glyphIndex,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ), applyCursive(
                    firstIndex: glyphIndex,
                    secondIndex: secondIndex,
                    rules: rules,
                    lookup: lookup,
                    feature: feature,
                    plan: plan,
                    glyphs: &glyphs
                ) else { continue }
                return true

            case .markToBase(let tableIndex):
                guard applyMarkToBase(
                    markIndex: glyphIndex,
                    tableIndex: tableIndex,
                    lookup: lookup,
                    feature: feature,
                    plan: plan,
                    definition: glyphDefinition,
                    requireMarkBase: false,
                    glyphs: &glyphs
                ) else { continue }
                return true

            case .markToMark(let tableIndex):
                guard applyMarkToBase(
                    markIndex: glyphIndex,
                    tableIndex: tableIndex,
                    lookup: lookup,
                    feature: feature,
                    plan: plan,
                    definition: glyphDefinition,
                    requireMarkBase: true,
                    glyphs: &glyphs
                ) else { continue }
                return true

            case .markToLigature(let tableIndex):
                guard applyMarkToLigature(
                    markIndex: glyphIndex,
                    tableIndex: tableIndex,
                    lookup: lookup,
                    feature: feature,
                    plan: plan,
                    definition: glyphDefinition,
                    glyphs: &glyphs
                ) else { continue }
                return true

            case .context(let rules):
                guard let ruleIndex = matchingContext(
                    rules: rules,
                    at: glyphIndex,
                    plan: plan,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ) else { continue }
                let rule = plan.context.rules[ruleIndex]
                for actionIndex in rule.actions {
                    let action = plan.context.actions[actionIndex]
                    guard let target = includedIndex(
                        startingAt: glyphIndex,
                        ordinal: action.sequenceIndex,
                        lookup: lookup,
                        definition: glyphDefinition,
                        glyphs: glyphs
                    ) else { continue }
                    _ = applyLookupAt(
                        action.lookupIndex,
                        at: target,
                        feature: feature,
                        depth: depth + 1,
                        plan: plan,
                        glyphDefinition: glyphDefinition,
                        glyphs: &glyphs
                    )
                }
                return true
            }
        }
        return false
    }

    private static func pairAdjustment(
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
                if plan.pairRules[middle].key < key {
                    lower = middle + 1
                } else {
                    upper = middle
                }
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

        default:
            return nil
        }
    }

    private static func applyCursive(
        firstIndex: Int,
        secondIndex: Int,
        rules: Range<Int>,
        lookup: OpenTypePositioningPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypePositioningPlan,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        guard let first = cursiveRule(glyphs[firstIndex].id.rawValue, rules: rules, plan: plan),
              let second = cursiveRule(glyphs[secondIndex].id.rawValue, rules: rules, plan: plan),
              let exit = first.exit,
              let entry = second.entry
        else { return false }

        let resolvedExit = exit.resolved(
            store: plan.variationStore,
            coordinates: plan.coordinates
        )
        let resolvedEntry = entry.resolved(
            store: plan.variationStore,
            coordinates: plan.coordinates
        )
        if lookup.flags.isRightToLeft {
            let advance = totalXAdvance(glyphs[secondIndex])
            glyphs[secondIndex].xAdvance += Int32(resolvedEntry.x)
                - Int32(resolvedExit.x) - advance
            glyphs[firstIndex].yPlacement = glyphs[secondIndex].yPlacement
                + Int32(resolvedEntry.y) - Int32(resolvedExit.y)
        } else {
            let advance = totalXAdvance(glyphs[firstIndex])
            glyphs[firstIndex].xAdvance += Int32(resolvedExit.x)
                - Int32(resolvedEntry.x) - advance
            glyphs[secondIndex].yPlacement = glyphs[firstIndex].yPlacement
                + Int32(resolvedExit.y) - Int32(resolvedEntry.y)
        }
        mark(&glyphs[firstIndex], lookup: lookup, feature: feature)
        mark(&glyphs[secondIndex], lookup: lookup, feature: feature)
        return true
    }

    private static func applyMarkToBase(
        markIndex: Int,
        tableIndex: Int,
        lookup: OpenTypePositioningPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypePositioningPlan,
        definition: borrowing SFNT.GlyphDefinition?,
        requireMarkBase: Bool,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        let table = plan.markBaseTables[tableIndex]
        guard let mark = markRule(
            glyphs[markIndex].id.rawValue,
            rules: table.marks,
            plan: plan
        ) else { return false }
        var candidate = markIndex
        while candidate > 0 {
            candidate -= 1
            if isIgnored(glyphs[candidate], by: lookup.flags, definition: definition) { continue }
            guard let base = baseRule(
                glyphs[candidate].id.rawValue,
                rules: table.bases,
                plan: plan
            ) else {
                if requireMarkBase { continue }
                return false
            }
            guard mark.markClass < base.anchors.count,
                  let baseAnchor = plan.anchors[base.anchors.lowerBound + mark.markClass]
            else { return false }
            attach(
                markIndex: markIndex,
                baseIndex: candidate,
                markAnchor: mark.anchor,
                baseAnchor: baseAnchor,
                plan: plan,
                glyphs: &glyphs
            )
            markGlyph(&glyphs[markIndex], lookup: lookup, feature: feature)
            return true
        }
        return false
    }

    private static func applyMarkToLigature(
        markIndex: Int,
        tableIndex: Int,
        lookup: OpenTypePositioningPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypePositioningPlan,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        let table = plan.markLigatureTables[tableIndex]
        guard let mark = markRule(
            glyphs[markIndex].id.rawValue,
            rules: table.marks,
            plan: plan
        ) else { return false }
        var candidate = markIndex
        while candidate > 0 {
            candidate -= 1
            if isIgnored(glyphs[candidate], by: lookup.flags, definition: definition) { continue }
            guard let ligature = ligatureRule(
                glyphs[candidate].id.rawValue,
                rules: table.ligatures,
                plan: plan
            ), !ligature.components.isEmpty else { return false }
            let requestedComponent = glyphs[markIndex].ligatureComponent
            let componentOffset = requestedComponent == 0
                ? ligature.components.count - 1
                : min(Int(requestedComponent - 1), ligature.components.count - 1)
            let componentIndex = ligature.components.lowerBound + componentOffset
            let component = plan.ligatureComponents[componentIndex]
            guard mark.markClass < component.anchors.count,
                  let baseAnchor = plan.anchors[
                    component.anchors.lowerBound + mark.markClass
                  ]
            else { return false }
            attach(
                markIndex: markIndex,
                baseIndex: candidate,
                markAnchor: mark.anchor,
                baseAnchor: baseAnchor,
                plan: plan,
                glyphs: &glyphs
            )
            markGlyph(&glyphs[markIndex], lookup: lookup, feature: feature)
            return true
        }
        return false
    }

    private static func attach(
        markIndex: Int,
        baseIndex: Int,
        markAnchor: SFNT.OpenTypeLayout.Anchor,
        baseAnchor: SFNT.OpenTypeLayout.Anchor,
        plan: borrowing OpenTypePositioningPlan,
        glyphs: inout GlyphBuffer
    ) {
        let markAnchor = markAnchor.resolved(
            store: plan.variationStore,
            coordinates: plan.coordinates
        )
        let baseAnchor = baseAnchor.resolved(
            store: plan.variationStore,
            coordinates: plan.coordinates
        )
        var interveningAdvance: Int32 = 0
        if baseIndex < markIndex {
            for index in baseIndex..<markIndex {
                interveningAdvance += totalXAdvance(glyphs[index])
            }
        }
        glyphs[markIndex].xPlacement = glyphs[baseIndex].xPlacement
            + Int32(baseAnchor.x) - Int32(markAnchor.x) - interveningAdvance
        glyphs[markIndex].yPlacement = glyphs[baseIndex].yPlacement
            + Int32(baseAnchor.y) - Int32(markAnchor.y)
    }

    private static func matchingContext(
        rules: Range<Int>,
        at index: Int,
        plan: borrowing OpenTypePositioningPlan,
        lookup: OpenTypePositioningPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        for ruleIndex in rules {
            let rule = plan.context.rules[ruleIndex]
            if let first = rule.firstMatcher,
               !plan.context.matches(first, glyph: glyphs[index].id.rawValue) {
                continue
            }
            var matches = true
            var candidate = index
            for offset in 0..<rule.input.count {
                if offset > 0 {
                    guard let next = nextIncluded(
                        after: candidate,
                        lookup: lookup,
                        definition: definition,
                        glyphs: glyphs
                    ) else { matches = false; break }
                    candidate = next
                }
                if !plan.context.matches(
                    rule.input.lowerBound + offset,
                    glyph: glyphs[candidate].id.rawValue
                ) {
                    matches = false
                    break
                }
            }
            if !matches { continue }
            candidate = index
            for offset in 0..<rule.backtrack.count {
                guard let previous = previousIncluded(
                    before: candidate,
                    lookup: lookup,
                    definition: definition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = previous
                if !plan.context.matches(
                    rule.backtrack.lowerBound + offset,
                    glyph: glyphs[candidate].id.rawValue
                ) {
                    matches = false
                    break
                }
            }
            if !matches { continue }
            candidate = index
            for _ in 1..<rule.input.count {
                guard let next = nextIncluded(
                    after: candidate,
                    lookup: lookup,
                    definition: definition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = next
            }
            if !matches { continue }
            for offset in 0..<rule.lookahead.count {
                guard let next = nextIncluded(
                    after: candidate,
                    lookup: lookup,
                    definition: definition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = next
                if !plan.context.matches(
                    rule.lookahead.lowerBound + offset,
                    glyph: glyphs[candidate].id.rawValue
                ) {
                    matches = false
                    break
                }
            }
            if matches { return ruleIndex }
        }
        return nil
    }

    private static func singleRule(
        _ glyph: UInt16,
        rules: Range<Int>,
        plan: borrowing OpenTypePositioningPlan
    ) -> OpenTypePositioningPlan.SingleRule? {
        binaryRule(glyph, range: rules, values: plan.singleRules, key: \.glyph)
    }

    private static func cursiveRule(
        _ glyph: UInt16,
        rules: Range<Int>,
        plan: borrowing OpenTypePositioningPlan
    ) -> OpenTypePositioningPlan.CursiveRule? {
        binaryRule(glyph, range: rules, values: plan.cursiveRules, key: \.glyph)
    }

    private static func markRule(
        _ glyph: UInt16,
        rules: Range<Int>,
        plan: borrowing OpenTypePositioningPlan
    ) -> OpenTypePositioningPlan.MarkRule? {
        binaryRule(glyph, range: rules, values: plan.markRules, key: \.glyph)
    }

    private static func baseRule(
        _ glyph: UInt16,
        rules: Range<Int>,
        plan: borrowing OpenTypePositioningPlan
    ) -> OpenTypePositioningPlan.BaseRule? {
        binaryRule(glyph, range: rules, values: plan.baseRules, key: \.glyph)
    }

    private static func ligatureRule(
        _ glyph: UInt16,
        rules: Range<Int>,
        plan: borrowing OpenTypePositioningPlan
    ) -> OpenTypePositioningPlan.LigatureRule? {
        binaryRule(glyph, range: rules, values: plan.ligatureRules, key: \.glyph)
    }

    private static func binaryRule<Value>(
        _ glyph: UInt16,
        range: Range<Int>,
        values: [Value],
        key: KeyPath<Value, UInt16>
    ) -> Value? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if values[middle][keyPath: key] < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < range.upperBound, values[lower][keyPath: key] == glyph else { return nil }
        return values[lower]
    }

    private static func nextIncluded(
        after index: Int,
        lookup: OpenTypePositioningPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        var next = index + 1
        while next < glyphs.count {
            if !isIgnored(glyphs[next], by: lookup.flags, definition: definition) { return next }
            next += 1
        }
        return nil
    }

    private static func previousIncluded(
        before index: Int,
        lookup: OpenTypePositioningPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        var previous = index - 1
        while previous >= 0 {
            if !isIgnored(glyphs[previous], by: lookup.flags, definition: definition) {
                return previous
            }
            previous -= 1
        }
        return nil
    }

    private static func includedIndex(
        startingAt start: Int,
        ordinal: Int,
        lookup: OpenTypePositioningPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        guard ordinal >= 0, start < glyphs.count else { return nil }
        var result = start
        for _ in 0..<ordinal {
            guard let next = nextIncluded(
                after: result,
                lookup: lookup,
                definition: definition,
                glyphs: glyphs
            ) else { return nil }
            result = next
        }
        return result
    }

    private static func isIgnored(
        _ glyph: ShapingGlyph,
        by flags: SFNT.OpenTypeLayout.LookupFlags,
        definition: borrowing SFNT.GlyphDefinition?
    ) -> Bool {
        guard flags.rawValue & 0xFF1E != 0 else { return false }
        return definition?.ignores(glyph: glyph.id.rawValue, flags: flags) ?? false
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

    private static func resolved(
        _ adjustment: SFNT.GlyphPositioning.ValueAdjustment,
        plan: borrowing OpenTypePositioningPlan
    ) -> SFNT.GlyphPositioning.ValueAdjustment {
        adjustment.resolved(
            store: plan.variationStore,
            coordinates: plan.coordinates
        )
    }

    private static func totalXAdvance(_ glyph: ShapingGlyph) -> Int32 {
        glyph.nominalXAdvance + glyph.xAdvance
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

    private static func mark(
        _ glyph: inout ShapingGlyph,
        lookup: OpenTypePositioningPlan.Lookup,
        feature: UInt32
    ) {
        glyph.lookupIndex = lookup.sourceIndex
        glyph.feature = feature
    }

    private static func markGlyph(
        _ glyph: inout ShapingGlyph,
        lookup: OpenTypePositioningPlan.Lookup,
        feature: UInt32
    ) {
        mark(&glyph, lookup: lookup, feature: feature)
    }
}

private extension SFNT.GlyphPositioning.ValueAdjustment {
    var isZero: Bool {
        xPlacement == 0 && yPlacement == 0 && xAdvance == 0 && yAdvance == 0
    }
}
