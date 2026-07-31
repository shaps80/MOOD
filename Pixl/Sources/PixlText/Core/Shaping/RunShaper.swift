enum RunShaper {
    static func shape(
        _ text: String,
        substitutionPlans: Span<OpenTypeShapingPlan>,
        positioningPlans: Span<OpenTypePositioningPlan>,
        registry: borrowing SFNT.Registry,
        workspace: inout ShapingWorkspace
    ) throws {
        workspace.removeOutput()
        try validate(workspace.inputRuns, sourceCount: text.utf8.count)

        for runIndex in 0..<workspace.inputRuns.count {
            let input = workspace.inputRuns[runIndex]
            guard let source = substring(of: text, in: input.sourceRange) else {
                throw RunShapingError.invalidSourceBoundary
            }

            workspace.scratch.glyphs.removeAll()
            workspace.scratch.scratch.removeAll()
            workspace.scratch.removeRenderBoundsCache()
            var sourceOffset = input.sourceRange.lowerBound

            var characterIndex = source.startIndex
            while characterIndex < source.endIndex {
                let next = source.index(after: characterIndex)
                let character = source[characterIndex..<next]
                let sourceRange = sourceOffset..<(sourceOffset + character.utf8.count)
                UnicodeNormalization.normalizeNFC(
                    character.unicodeScalars,
                    using: &workspace.normalization
                )

                for scalar in workspace.normalization.normalized {
                    let glyph = registry.glyphID(for: scalar, in: input.face)
                        ?? .init(rawValue: 0)
                    workspace.scratch.glyphs.append(.init(
                        id: glyph,
                        sourceRange: sourceRange,
                        lookupIndex: nil,
                        feature: nil
                    ))
                }
                sourceOffset = sourceRange.upperBound
                characterIndex = next
            }

            if let planIndex = input.substitutionPlanIndex {
                guard substitutionPlans.indices.contains(planIndex) else {
                    throw RunShapingError.invalidRunRanges
                }
                OpenTypeShaper.apply(
                    substitutionPlans[planIndex],
                    glyphDefinition: registry.glyphDefinition(in: input.face),
                    workspace: &workspace.scratch
                )
            }
            for glyphIndex in 0..<workspace.scratch.glyphs.count {
                let glyph = workspace.scratch.glyphs[glyphIndex].id
                workspace.scratch.glyphs[glyphIndex].nominalXAdvance = Int32(
                    registry.advanceInFontUnits(for: glyph, in: input.face) ?? 0
                )
            }
            if let planIndex = input.positioningPlanIndex {
                guard positioningPlans.indices.contains(planIndex) else {
                    throw RunShapingError.invalidRunRanges
                }
                OpenTypePositioner.apply(
                    positioningPlans[planIndex],
                    glyphDefinition: registry.glyphDefinition(in: input.face),
                    to: &workspace.scratch.glyphs
                )
            }
            for glyphIndex in 0..<workspace.scratch.glyphs.count {
                let glyph = workspace.scratch.glyphs[glyphIndex].id
                let bounds = renderBounds(
                    for: glyph,
                    face: input.face,
                    registry: registry,
                    scratch: &workspace.scratch
                )
                workspace.scratch.glyphs[glyphIndex].renderBounds = bounds
            }

            let glyphStart = workspace.glyphs.count
            workspace.glyphs.append(contentsOf: workspace.scratch.glyphs)
            let ellipsisGlyphRange = shapeInsertionToken(
                primary: "…",
                fallback: ".",
                fallbackCount: 3,
                input: input,
                substitutionPlans: substitutionPlans,
                positioningPlans: positioningPlans,
                registry: registry,
                workspace: &workspace
            )
            let hyphenGlyphRange = shapeInsertionToken(
                primary: "‐",
                fallback: "-",
                fallbackCount: 1,
                input: input,
                substitutionPlans: substitutionPlans,
                positioningPlans: positioningPlans,
                registry: registry,
                workspace: &workspace
            )
            workspace.runs.append(.init(
                sourceRange: input.sourceRange,
                glyphRange: glyphStart..<workspace.glyphs.count,
                face: input.face,
                size: input.size,
                direction: input.direction,
                script: input.script,
                language: input.language,
                ellipsisGlyphRange: ellipsisGlyphRange,
                hyphenGlyphRange: hyphenGlyphRange
            ))
        }
    }

    private static func shapeInsertionToken(
        primary: Unicode.Scalar,
        fallback: Unicode.Scalar,
        fallbackCount: Int,
        input: TextRun,
        substitutionPlans: Span<OpenTypeShapingPlan>,
        positioningPlans: Span<OpenTypePositioningPlan>,
        registry: borrowing SFNT.Registry,
        workspace: inout ShapingWorkspace
    ) -> Range<Int> {
        workspace.scratch.glyphs.removeAll()
        workspace.scratch.scratch.removeAll()
        if let glyph = registry.glyphID(for: primary, in: input.face) {
            workspace.scratch.glyphs.append(.init(
                id: glyph,
                sourceRange: 0..<0,
                lookupIndex: nil,
                feature: nil
            ))
        } else {
            let glyph = registry.glyphID(for: fallback, in: input.face)
                ?? .init(rawValue: 0)
            for _ in 0..<fallbackCount {
                workspace.scratch.glyphs.append(.init(
                    id: glyph,
                    sourceRange: 0..<0,
                    lookupIndex: nil,
                    feature: nil
                ))
            }
        }

        if let planIndex = input.substitutionPlanIndex,
           substitutionPlans.indices.contains(planIndex) {
            OpenTypeShaper.apply(
                substitutionPlans[planIndex],
                glyphDefinition: registry.glyphDefinition(in: input.face),
                workspace: &workspace.scratch
            )
        }
        for index in 0..<workspace.scratch.glyphs.count {
            let glyph = workspace.scratch.glyphs[index].id
            workspace.scratch.glyphs[index].nominalXAdvance = Int32(
                registry.advanceInFontUnits(for: glyph, in: input.face) ?? 0
            )
        }
        if let planIndex = input.positioningPlanIndex,
           positioningPlans.indices.contains(planIndex) {
            OpenTypePositioner.apply(
                positioningPlans[planIndex],
                glyphDefinition: registry.glyphDefinition(in: input.face),
                to: &workspace.scratch.glyphs
            )
        }
        for glyphIndex in 0..<workspace.scratch.glyphs.count {
            let glyph = workspace.scratch.glyphs[glyphIndex].id
            let bounds = renderBounds(
                for: glyph,
                face: input.face,
                registry: registry,
                scratch: &workspace.scratch
            )
            workspace.scratch.glyphs[glyphIndex].renderBounds = bounds
        }

        let start = workspace.insertionGlyphs.count
        workspace.insertionGlyphs.append(contentsOf: workspace.scratch.glyphs)
        return start..<workspace.insertionGlyphs.count
    }

    private static func renderBounds(
        for glyph: GlyphID,
        face: SFNT.Face,
        registry: borrowing SFNT.Registry,
        scratch: inout ShapingScratch
    ) -> SFNT.GlyphBounds? {
        for index in scratch.renderBoundsGlyphs.indices
            where scratch.renderBoundsGlyphs[index] == glyph {
            return scratch.renderBoundsValues[index]
        }
        let bounds = registry.renderBounds(for: glyph, in: face)
        if scratch.renderBoundsGlyphs.count < ShapingScratch.renderBoundsCapacity {
            scratch.renderBoundsGlyphs.append(glyph)
            scratch.renderBoundsValues.append(bounds)
        }
        return bounds
    }

    private static func validate(
        _ runs: borrowing TextRunBuffer,
        sourceCount: Int
    ) throws {
        if runs.count == 0 {
            guard sourceCount == 0 else { throw RunShapingError.invalidRunRanges }
            return
        }
        var expectedLowerBound = 0
        for index in 0..<runs.count {
            let range = runs[index].sourceRange
            guard range.lowerBound == expectedLowerBound,
                  !range.isEmpty,
                  range.upperBound <= sourceCount,
                  runs[index].size > 0
            else {
                throw RunShapingError.invalidRunRanges
            }
            expectedLowerBound = range.upperBound
        }
        guard expectedLowerBound == sourceCount else {
            throw RunShapingError.invalidRunRanges
        }
    }

    private static func substring(
        of text: String,
        in range: Range<Int>
    ) -> Substring? {
        let utf8 = text.utf8
        let lowerUTF8 = utf8.index(utf8.startIndex, offsetBy: range.lowerBound)
        let upperUTF8 = utf8.index(lowerUTF8, offsetBy: range.count)
        guard let lower = lowerUTF8.samePosition(in: text),
              let upper = upperUTF8.samePosition(in: text)
        else {
            return nil
        }
        return text[lower..<upper]
    }
}
