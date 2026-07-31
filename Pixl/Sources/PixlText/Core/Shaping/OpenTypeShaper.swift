enum OpenTypeShaper {
    private static let maximumContextDepth = 64

    static func apply(
        _ plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition? = nil,
        workspace: inout ShapingScratch
    ) {
        for execution in plan.executions where plan.lookups.indices.contains(execution.lookupIndex) {
            applyTopLevelLookup(
                execution.lookupIndex,
                feature: execution.feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                workspace: &workspace
            )
        }
    }

    private static func applyTopLevelLookup(
        _ lookupIndex: Int,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        workspace: inout ShapingScratch
    ) {
        let lookup = plan.lookups[lookupIndex]
        switch lookup.kind {
        case .none:
            break
        case .single:
            applySingle(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                to: &workspace.glyphs
            )
        case .multiple:
            applyMultiple(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                workspace: &workspace
            )
        case .alternate:
            applyAlternate(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                to: &workspace.glyphs
            )
        case .ligature:
            applyLigatures(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                workspace: &workspace
            )
        case .context:
            applyContexts(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                to: &workspace.glyphs
            )
        case .reverse:
            applyReverse(
                lookup,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                to: &workspace.glyphs
            )
        }
    }

    private static func applySingle(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        to glyphs: inout GlyphBuffer
    ) {
        for index in 0..<glyphs.count {
            guard !isIgnored(glyphs[index], by: lookup.flags, definition: glyphDefinition) else {
                continue
            }
            guard let rule = singleRule(
                for: glyphs[index].id.rawValue,
                in: lookup.rules,
                rules: plan.singleRules
            ) else { continue }
            glyphs[index].id = .init(rawValue: rule.output)
            glyphs[index].lookupIndex = lookup.sourceIndex
            glyphs[index].feature = feature
        }
    }

    private static func applyMultiple(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        workspace: inout ShapingScratch
    ) {
        workspace.scratch.removeAll()
        for index in 0..<workspace.glyphs.count {
            let source = workspace.glyphs[index]
            guard !isIgnored(source, by: lookup.flags, definition: glyphDefinition) else {
                workspace.scratch.append(source)
                continue
            }
            guard let rule = sequenceRule(
                for: source.id.rawValue,
                in: lookup.rules,
                rules: plan.multipleRules
            ) else {
                workspace.scratch.append(source)
                continue
            }
            for outputIndex in rule.outputs {
                workspace.scratch.append(.init(
                    id: .init(rawValue: plan.multipleOutputs[outputIndex]),
                    sourceRange: source.sourceRange,
                    lookupIndex: lookup.sourceIndex,
                    feature: feature
                ))
            }
        }
        workspace.swapBuffers()
        workspace.scratch.removeAll()
    }

    private static func applyAlternate(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        to glyphs: inout GlyphBuffer
    ) {
        for index in 0..<glyphs.count {
            guard !isIgnored(glyphs[index], by: lookup.flags, definition: glyphDefinition) else {
                continue
            }
            guard let rule = sequenceRule(
                for: glyphs[index].id.rawValue,
                in: lookup.rules,
                rules: plan.alternateRules
            ), let outputIndex = rule.outputs.first
            else { continue }
            glyphs[index].id = .init(rawValue: plan.alternateOutputs[outputIndex])
            glyphs[index].lookupIndex = lookup.sourceIndex
            glyphs[index].feature = feature
        }
    }

    private static func applyLigatures(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        workspace: inout ShapingScratch
    ) {
        var read = 0
        workspace.scratch.removeAll()
        while read < workspace.glyphs.count {
            let source = workspace.glyphs[read]
            guard !isIgnored(source, by: lookup.flags, definition: glyphDefinition) else {
                workspace.scratch.append(source)
                read += 1
                continue
            }
            if let match = matchingLigature(
                at: read,
                rules: lookup.rules,
                plan: plan,
                lookup: lookup,
                glyphDefinition: glyphDefinition,
                glyphs: workspace.glyphs
            ) {
                var ligature = ShapingGlyph(
                    id: .init(rawValue: match.rule.output),
                    sourceRange: Range(uncheckedBounds: (
                        source.sourceRange.lowerBound,
                        workspace.glyphs[match.lastIndex].sourceRange.upperBound
                    )),
                    lookupIndex: lookup.sourceIndex,
                    feature: feature
                )
                ligature.ligatureComponentCount = UInt16(clamping: match.rule.components.count)
                workspace.scratch.append(ligature)

                var component: UInt16 = 1
                if read < match.lastIndex {
                    for retainedIndex in (read + 1)...match.lastIndex {
                        var retained = workspace.glyphs[retainedIndex]
                        if isIgnored(retained, by: lookup.flags, definition: glyphDefinition) {
                            retained.ligatureComponent = component
                            workspace.scratch.append(retained)
                        } else {
                            component &+= 1
                        }
                    }
                }
                read = match.lastIndex + 1
            } else {
                workspace.scratch.append(source)
                read += 1
            }
        }
        workspace.swapBuffers()
        workspace.scratch.removeAll()
    }

    private static func applyContexts(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        to glyphs: inout GlyphBuffer
    ) {
        var index = 0
        while index < glyphs.count {
            guard let ruleIndex = matchingContext(
                rules: lookup.rules,
                at: index,
                plan: plan,
                lookup: lookup,
                glyphDefinition: glyphDefinition,
                glyphs: glyphs
            ) else {
                index += 1
                continue
            }
            let inputCount = plan.context.rules[ruleIndex].input.count
            let before = glyphs.count
            applyActions(
                ruleIndex,
                at: index,
                feature: feature,
                depth: 0,
                plan: plan,
                glyphDefinition: glyphDefinition,
                outerLookup: lookup,
                glyphs: &glyphs
            )
            index += max(1, inputCount + glyphs.count - before)
        }
    }

    private static func applyReverse(
        _ lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        to glyphs: inout GlyphBuffer
    ) {
        guard glyphs.count > 0 else { return }
        for index in stride(from: glyphs.count - 1, through: 0, by: -1) {
            guard !isIgnored(glyphs[index], by: lookup.flags, definition: glyphDefinition) else {
                continue
            }
            _ = applyReverseAt(
                lookup,
                at: index,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                glyphs: &glyphs
            )
        }
    }

    private static func applyLookupAt(
        _ lookupIndex: Int,
        at index: Int,
        feature: UInt32,
        depth: Int,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        guard depth < maximumContextDepth,
              plan.lookups.indices.contains(lookupIndex),
              glyphs.count > index
        else { return false }
        let lookup = plan.lookups[lookupIndex]
        guard !isIgnored(glyphs[index], by: lookup.flags, definition: glyphDefinition) else {
            return false
        }
        switch lookup.kind {
        case .none:
            return false
        case .single:
            guard let rule = singleRule(
                for: glyphs[index].id.rawValue,
                in: lookup.rules,
                rules: plan.singleRules
            ) else { return false }
            glyphs[index].id = .init(rawValue: rule.output)
            mark(&glyphs[index], lookup: lookup, feature: feature)
            return true

        case .multiple:
            guard let rule = sequenceRule(
                for: glyphs[index].id.rawValue,
                in: lookup.rules,
                rules: plan.multipleRules
            ) else { return false }
            let sourceRange = glyphs[index].sourceRange
            glyphs.replace(
                index..<(index + 1),
                with: plan.multipleOutputs,
                from: rule.outputs,
                sourceRange: sourceRange,
                lookupIndex: lookup.sourceIndex,
                feature: feature
            )
            return true

        case .alternate:
            guard let rule = sequenceRule(
                for: glyphs[index].id.rawValue,
                in: lookup.rules,
                rules: plan.alternateRules
            ), let outputIndex = rule.outputs.first
            else { return false }
            glyphs[index].id = .init(rawValue: plan.alternateOutputs[outputIndex])
            mark(&glyphs[index], lookup: lookup, feature: feature)
            return true

        case .ligature:
            guard let match = matchingLigature(
                at: index,
                rules: lookup.rules,
                plan: plan,
                lookup: lookup,
                glyphDefinition: glyphDefinition,
                glyphs: glyphs
            ) else { return false }
            let sourceRange = Range(uncheckedBounds: (
                glyphs[index].sourceRange.lowerBound,
                glyphs[match.lastIndex].sourceRange.upperBound
            ))
            compactLigature(
                match,
                at: index,
                sourceRange: sourceRange,
                lookup: lookup,
                feature: feature,
                glyphDefinition: glyphDefinition,
                glyphs: &glyphs
            )
            return true

        case .context:
            guard let rule = matchingContext(
                rules: lookup.rules,
                at: index,
                plan: plan,
                lookup: lookup,
                glyphDefinition: glyphDefinition,
                glyphs: glyphs
            ) else { return false }
            applyActions(
                rule,
                at: index,
                feature: feature,
                depth: depth + 1,
                plan: plan,
                glyphDefinition: glyphDefinition,
                outerLookup: lookup,
                glyphs: &glyphs
            )
            return true

        case .reverse:
            return applyReverseAt(
                lookup,
                at: index,
                feature: feature,
                plan: plan,
                glyphDefinition: glyphDefinition,
                glyphs: &glyphs
            )
        }
    }

    private static func applyActions(
        _ ruleIndex: Int,
        at index: Int,
        feature: UInt32,
        depth: Int,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        outerLookup: OpenTypeShapingPlan.Lookup,
        glyphs: inout GlyphBuffer
    ) {
        let rule = plan.context.rules[ruleIndex]
        for actionIndex in rule.actions {
            let action = plan.context.actions[actionIndex]
            guard let target = includedIndex(
                startingAt: index,
                ordinal: action.sequenceIndex,
                lookup: outerLookup,
                definition: glyphDefinition,
                glyphs: glyphs
            ) else { continue }
            _ = applyLookupAt(
                action.lookupIndex,
                at: target,
                feature: feature,
                depth: depth,
                plan: plan,
                glyphDefinition: glyphDefinition,
                glyphs: &glyphs
            )
        }
    }

    private static func applyReverseAt(
        _ lookup: OpenTypeShapingPlan.Lookup,
        at index: Int,
        feature: UInt32,
        plan: borrowing OpenTypeShapingPlan,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        glyphs: inout GlyphBuffer
    ) -> Bool {
        for ruleIndex in lookup.rules {
            let rule = plan.reverseRules[ruleIndex]
            guard let coverageIndex = plan.context.coverageIndex(
                of: glyphs[index].id.rawValue,
                coverage: rule.inputCoverage
            ), coverageIndex < rule.outputs.count,
                  hasSurroundingGlyphs(
                    at: index,
                    backtrackCount: rule.backtrackCoverages.count,
                    lookaheadCount: rule.lookaheadCoverages.count,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                  )
            else { continue }
            var matches = true
            var candidate = index
            for offset in 0..<rule.backtrackCoverages.count {
                guard let previous = previousIncluded(
                    before: candidate,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = previous
                if
                plan.context.coverageIndex(
                    of: glyphs[candidate].id.rawValue,
                    coverage: plan.reverseCoverageIndices[
                        rule.backtrackCoverages.lowerBound + offset
                    ]
                ) == nil { matches = false; break }
            }
            if !matches { continue }
            candidate = index
            for offset in 0..<rule.lookaheadCoverages.count {
                guard let next = nextIncluded(
                    after: candidate,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = next
                if
                plan.context.coverageIndex(
                    of: glyphs[candidate].id.rawValue,
                    coverage: plan.reverseCoverageIndices[
                        rule.lookaheadCoverages.lowerBound + offset
                    ]
                ) == nil { matches = false; break }
            }
            if !matches { continue }
            glyphs[index].id = .init(
                rawValue: plan.reverseOutputs[rule.outputs.lowerBound + coverageIndex]
            )
            mark(&glyphs[index], lookup: lookup, feature: feature)
            return true
        }
        return false
    }

    private static func matchingContext(
        rules: Range<Int>,
        at index: Int,
        plan: borrowing OpenTypeShapingPlan,
        lookup: OpenTypeShapingPlan.Lookup,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
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
                        definition: glyphDefinition,
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
                    definition: glyphDefinition,
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
                    definition: glyphDefinition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = next
            }
            if !matches { continue }
            for offset in 0..<rule.lookahead.count {
                guard let next = nextIncluded(
                    after: candidate,
                    lookup: lookup,
                    definition: glyphDefinition,
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
        for glyph: UInt16,
        in range: Range<Int>,
        rules: [OpenTypeShapingPlan.SingleRule]
    ) -> OpenTypeShapingPlan.SingleRule? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if rules[middle].input < glyph { lower = middle + 1 } else { upper = middle }
        }
        guard lower < range.upperBound, rules[lower].input == glyph else { return nil }
        return rules[lower]
    }

    private static func sequenceRule(
        for glyph: UInt16,
        in range: Range<Int>,
        rules: [OpenTypeShapingPlan.SequenceRule]
    ) -> OpenTypeShapingPlan.SequenceRule? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if rules[middle].input < glyph { lower = middle + 1 } else { upper = middle }
        }
        guard lower < range.upperBound, rules[lower].input == glyph else { return nil }
        return rules[lower]
    }

    private static func matchingLigature(
        at glyphIndex: Int,
        rules: Range<Int>,
        plan: borrowing OpenTypeShapingPlan,
        lookup: OpenTypeShapingPlan.Lookup,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> (rule: OpenTypeShapingPlan.LigatureRule, lastIndex: Int)? {
        let first = glyphs[glyphIndex].id.rawValue
        var lower = rules.lowerBound
        var upper = rules.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if plan.ligatureRules[middle].first < first {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        var ruleIndex = lower
        while ruleIndex < rules.upperBound {
            let rule = plan.ligatureRules[ruleIndex]
            guard rule.first == first else { break }
            var candidate = glyphIndex
            var matches = true
            for componentIndex in 1..<rule.components.count {
                guard let next = nextIncluded(
                    after: candidate,
                    lookup: lookup,
                    definition: glyphDefinition,
                    glyphs: glyphs
                ) else { matches = false; break }
                candidate = next
                if glyphs[candidate].id.rawValue
                    != plan.ligatureComponents[rule.components.lowerBound + componentIndex] {
                    matches = false
                    break
                }
            }
            if matches { return (rule, candidate) }
            ruleIndex += 1
        }
        return nil
    }

    private static func compactLigature(
        _ match: (rule: OpenTypeShapingPlan.LigatureRule, lastIndex: Int),
        at firstIndex: Int,
        sourceRange: Range<Int>,
        lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32,
        glyphDefinition: borrowing SFNT.GlyphDefinition?,
        glyphs: inout GlyphBuffer
    ) {
        let originalCount = glyphs.count
        var ligature = ShapingGlyph(
            id: .init(rawValue: match.rule.output),
            sourceRange: sourceRange,
            lookupIndex: lookup.sourceIndex,
            feature: feature
        )
        ligature.ligatureComponentCount = UInt16(clamping: match.rule.components.count)
        glyphs[firstIndex] = ligature
        var write = firstIndex + 1
        var component: UInt16 = 1
        if firstIndex < match.lastIndex {
            for read in (firstIndex + 1)...match.lastIndex {
                var glyph = glyphs[read]
                if isIgnored(glyph, by: lookup.flags, definition: glyphDefinition) {
                    glyph.ligatureComponent = component
                    glyphs[write] = glyph
                    write += 1
                } else {
                    component &+= 1
                }
            }
        }
        if match.lastIndex + 1 < originalCount {
            for read in (match.lastIndex + 1)..<originalCount {
                glyphs[write] = glyphs[read]
                write += 1
            }
        }
        glyphs.removeLast(originalCount - write)
    }

    private static func includedIndex(
        startingAt start: Int,
        ordinal: Int,
        lookup: OpenTypeShapingPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        guard ordinal >= 0, start < glyphs.count else { return nil }
        var candidate = start
        var remaining = ordinal
        while remaining > 0 {
            guard let next = nextIncluded(
                after: candidate,
                lookup: lookup,
                definition: definition,
                glyphs: glyphs
            ) else { return nil }
            candidate = next
            remaining -= 1
        }
        return candidate
    }

    private static func nextIncluded(
        after index: Int,
        lookup: OpenTypeShapingPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        var candidate = index + 1
        while candidate < glyphs.count {
            if !isIgnored(glyphs[candidate], by: lookup.flags, definition: definition) {
                return candidate
            }
            candidate += 1
        }
        return nil
    }

    private static func previousIncluded(
        before index: Int,
        lookup: OpenTypeShapingPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Int? {
        var candidate = index - 1
        while candidate >= 0 {
            if !isIgnored(glyphs[candidate], by: lookup.flags, definition: definition) {
                return candidate
            }
            candidate -= 1
        }
        return nil
    }

    private static func hasSurroundingGlyphs(
        at index: Int,
        backtrackCount: Int,
        lookaheadCount: Int,
        lookup: OpenTypeShapingPlan.Lookup,
        definition: borrowing SFNT.GlyphDefinition?,
        glyphs: borrowing GlyphBuffer
    ) -> Bool {
        var candidate = index
        for _ in 0..<backtrackCount {
            guard let previous = previousIncluded(
                before: candidate,
                lookup: lookup,
                definition: definition,
                glyphs: glyphs
            ) else { return false }
            candidate = previous
        }
        candidate = index
        for _ in 0..<lookaheadCount {
            guard let next = nextIncluded(
                after: candidate,
                lookup: lookup,
                definition: definition,
                glyphs: glyphs
            ) else { return false }
            candidate = next
        }
        return true
    }

    private static func isIgnored(
        _ glyph: ShapingGlyph,
        by flags: SFNT.OpenTypeLayout.LookupFlags,
        definition: borrowing SFNT.GlyphDefinition?
    ) -> Bool {
        let filteringBits = flags.rawValue & 0xFF1E
        guard filteringBits != 0 else { return false }
        return definition?.ignores(glyph: glyph.id.rawValue, flags: flags) ?? false
    }

    private static func mark(
        _ glyph: inout ShapingGlyph,
        lookup: OpenTypeShapingPlan.Lookup,
        feature: UInt32
    ) {
        glyph.lookupIndex = lookup.sourceIndex
        glyph.feature = feature
    }
}
