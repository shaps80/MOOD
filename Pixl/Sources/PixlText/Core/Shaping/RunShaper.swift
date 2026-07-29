enum RunShaper {
    static func shape(
        _ text: String,
        runs inputRuns: Span<TextRun>,
        substitutionPlans: Span<OpenTypeShapingPlan>,
        positioningPlans: Span<OpenTypePositioningPlan>,
        registry: borrowing SFNT.Registry,
        workspace: inout RunShapingWorkspace
    ) throws {
        workspace.removeAll()
        try validate(inputRuns, sourceCount: text.utf8.count)

        for runIndex in inputRuns.indices {
            let input = inputRuns[runIndex]
            guard let source = substring(of: text, in: input.sourceRange) else {
                throw RunShapingError.invalidSourceBoundary
            }

            workspace.run.glyphs.removeAll()
            workspace.run.scratch.removeAll()
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
                    workspace.run.glyphs.append(.init(
                        id: glyph,
                        sourceRange: sourceRange,
                        lookupIndex: nil,
                        feature: nil,
                        nominalXAdvance: Int32(
                            registry.advanceInFontUnits(for: glyph, in: input.face) ?? 0
                        )
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
                    workspace: &workspace.run
                )
            }
            for glyphIndex in 0..<workspace.run.glyphs.count {
                let glyph = workspace.run.glyphs[glyphIndex].id
                workspace.run.glyphs[glyphIndex].nominalXAdvance = Int32(
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
                    to: &workspace.run.glyphs
                )
            }

            let glyphStart = workspace.glyphs.count
            workspace.glyphs.append(contentsOf: workspace.run.glyphs)
            workspace.runs.append(.init(
                sourceRange: input.sourceRange,
                glyphRange: glyphStart..<workspace.glyphs.count,
                face: input.face,
                size: input.size,
                direction: input.direction,
                script: input.script,
                language: input.language
            ))
        }
    }

    private static func validate(
        _ runs: Span<TextRun>,
        sourceCount: Int
    ) throws {
        if runs.isEmpty {
            guard sourceCount == 0 else { throw RunShapingError.invalidRunRanges }
            return
        }
        var expectedLowerBound = 0
        for index in runs.indices {
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
