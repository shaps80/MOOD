enum LineComposer {
    static func positionFirstLine(
        sourceUTF8Count: Int,
        maximumWidth: Float,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>,
        units: Span<LineBreakUnit>,
        registry: borrowing SFNT.Registry,
        workspace: inout LineLayoutWorkspace
    ) throws -> PositionedLine {
        workspace.removeAll()
        try validate(
            sourceUTF8Count: sourceUTF8Count,
            maximumWidth: maximumWidth,
            glyphs: glyphs,
            runs: runs,
            opportunities: opportunities
        )

        if glyphs.isEmpty {
            return .init(
                consumedSourceRange: 0..<0,
                consumedGlyphRange: 0..<0,
                visibleGlyphRange: 0..<0,
                breakKind: .mandatory,
                advance: 0,
                ascent: 0,
                descent: 0,
                leading: 0,
                baselineOffset: 0,
                typographicBounds: .init(x: 0, y: 0, width: 0, height: 0),
                renderBounds: nil
            )
        }

        var penX: Float = 0
        var visibleAdvance: Float = 0
        var visibleGlyphEnd = 0
        var ascent: Float = 0
        var descent: Float = 0
        var leading: Float = 0
        var renderBounds: PositionedLine.Bounds?
        var runIndex = 0
        var unitIndex = 0
        var opportunityIndex = 0
        var glyphIndex = 0
        var lastFittingCandidate: Candidate?

        while glyphIndex < glyphs.count {
            let clusterRange = glyphs[glyphIndex].sourceRange
            var clusterEnd = glyphIndex + 1
            while clusterEnd < glyphs.count,
                  glyphs[clusterEnd].sourceRange == clusterRange {
                clusterEnd += 1
            }

            while unitIndex < units.count,
                  units[unitIndex].sourceOffset < clusterRange.lowerBound {
                unitIndex += 1
            }
            let attributes = clusterAttributes(
                sourceRange: clusterRange,
                startingAt: unitIndex,
                units: units
            )

            for index in glyphIndex..<clusterEnd {
                while runIndex < runs.count,
                      index >= runs[runIndex].glyphRange.upperBound {
                    runIndex += 1
                }
                guard runIndex < runs.count,
                      runs[runIndex].glyphRange.contains(index)
                else {
                    throw LineLayoutError.invalidInput
                }

                let run = runs[runIndex]
                let glyph = glyphs[index]
                let scale = run.size / Float(run.face.metrics.unitsPerEm)
                let metrics = run.face.metrics.scaled(to: run.size)
                ascent = max(ascent, metrics.ascent)
                descent = max(descent, metrics.descent)
                leading = max(leading, metrics.leading)

                let position = PositionedGlyph(
                    x: penX + Float(glyph.xPlacement) * scale,
                    y: -Float(glyph.yPlacement) * scale
                )
                workspace.positions.append(position)

                if attributes.isVisible,
                   let rawBounds = registry.renderBounds(for: glyph.id, in: run.face) {
                    let bounds = PositionedLine.Bounds(
                        x: position.x + Float(rawBounds.xMin) * scale,
                        y: position.y - Float(rawBounds.yMax) * scale,
                        width: Float(rawBounds.xMax - rawBounds.xMin) * scale,
                        height: Float(rawBounds.yMax - rawBounds.yMin) * scale
                    )
                    renderBounds = union(renderBounds, bounds)
                }

                if attributes.consumesAdvance {
                    penX += Float(glyph.nominalXAdvance + glyph.xAdvance) * scale
                }
            }

            if attributes.isVisible {
                visibleGlyphEnd = clusterEnd
                visibleAdvance = penX
            }

            while opportunityIndex < opportunities.count,
                  opportunities[opportunityIndex].sourceOffset < clusterRange.upperBound {
                opportunityIndex += 1
            }
            while opportunityIndex < opportunities.count,
                  opportunities[opportunityIndex].sourceOffset == clusterRange.upperBound {
                let opportunity = opportunities[opportunityIndex]
                let candidate = Candidate(
                    sourceEnd: opportunity.sourceOffset,
                    glyphEnd: clusterEnd,
                    visibleGlyphEnd: visibleGlyphEnd,
                    breakKind: opportunity.kind,
                    advance: visibleAdvance,
                    ascent: ascent,
                    descent: descent,
                    leading: leading,
                    renderBounds: renderBounds
                )

                if candidate.advance > maximumWidth {
                    return finish(lastFittingCandidate ?? candidate, workspace: &workspace)
                }
                if opportunity.kind == .mandatory {
                    return finish(candidate, workspace: &workspace)
                }
                lastFittingCandidate = candidate
                opportunityIndex += 1
            }

            glyphIndex = clusterEnd
        }

        guard let candidate = lastFittingCandidate else {
            throw LineLayoutError.invalidInput
        }
        return finish(candidate, workspace: &workspace)
    }

    private struct Candidate {
        let sourceEnd: Int
        let glyphEnd: Int
        let visibleGlyphEnd: Int
        let breakKind: LineBreakKind
        let advance: Float
        let ascent: Float
        let descent: Float
        let leading: Float
        let renderBounds: PositionedLine.Bounds?
    }

    private struct ClusterAttributes {
        let isVisible: Bool
        let consumesAdvance: Bool
    }

    private static func clusterAttributes(
        sourceRange: Range<Int>,
        startingAt start: Int,
        units: Span<LineBreakUnit>
    ) -> ClusterAttributes {
        var index = start
        var hasVisibleScalar = false
        var hasSpace = false
        while index < units.count, units[index].sourceOffset < sourceRange.upperBound {
            let unit = units[index]
            if unit.raw == .sp {
                hasSpace = true
            } else if !isNonRendering(unit) {
                hasVisibleScalar = true
            }
            index += 1
        }
        return .init(
            isVisible: hasVisibleScalar,
            consumesAdvance: hasVisibleScalar || hasSpace
        )
    }

    private static func isNonRendering(_ unit: LineBreakUnit) -> Bool {
        if unit.scalar == 0x00AD || unit.scalar == 0x2060 { return true }
        return [.bk, .cr, .lf, .nl, .zw, .wj].contains(unit.raw)
    }

    private static func finish(
        _ candidate: Candidate,
        workspace: inout LineLayoutWorkspace
    ) -> PositionedLine {
        let excess = workspace.positions.count - candidate.glyphEnd
        workspace.positions.removeLast(excess)
        return .init(
            consumedSourceRange: 0..<candidate.sourceEnd,
            consumedGlyphRange: 0..<candidate.glyphEnd,
            visibleGlyphRange: 0..<candidate.visibleGlyphEnd,
            breakKind: candidate.breakKind,
            advance: candidate.advance,
            ascent: candidate.ascent,
            descent: candidate.descent,
            leading: candidate.leading,
            baselineOffset: candidate.ascent,
            typographicBounds: .init(
                x: 0,
                y: -candidate.ascent,
                width: candidate.advance,
                height: candidate.ascent + candidate.descent
            ),
            renderBounds: candidate.renderBounds
        )
    }

    private static func union(
        _ lhs: PositionedLine.Bounds?,
        _ rhs: PositionedLine.Bounds
    ) -> PositionedLine.Bounds {
        guard let lhs else { return rhs }
        let minX = min(lhs.x, rhs.x)
        let minY = min(lhs.y, rhs.y)
        let maxX = max(lhs.x + lhs.width, rhs.x + rhs.width)
        let maxY = max(lhs.y + lhs.height, rhs.y + rhs.height)
        return .init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func validate(
        sourceUTF8Count: Int,
        maximumWidth: Float,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>
    ) throws {
        guard sourceUTF8Count >= 0,
              maximumWidth >= 0,
              maximumWidth.isFinite,
              !opportunities.isEmpty,
              opportunities[opportunities.count - 1].sourceOffset == sourceUTF8Count,
              opportunities[opportunities.count - 1].kind == .mandatory
        else {
            throw LineLayoutError.invalidInput
        }

        if glyphs.isEmpty {
            guard sourceUTF8Count == 0, runs.isEmpty else {
                throw LineLayoutError.invalidInput
            }
            return
        }

        guard !runs.isEmpty else { throw LineLayoutError.invalidInput }
        var expectedGlyphStart = 0
        var expectedSourceStart = 0
        for index in runs.indices {
            let run = runs[index]
            guard run.direction == .leftToRight else {
                throw LineLayoutError.unsupportedDirection
            }
            guard run.glyphRange.lowerBound == expectedGlyphStart,
                  run.sourceRange.lowerBound == expectedSourceStart,
                  run.glyphRange.upperBound <= glyphs.count,
                  run.sourceRange.upperBound <= sourceUTF8Count
            else {
                throw LineLayoutError.invalidInput
            }
            expectedGlyphStart = run.glyphRange.upperBound
            expectedSourceStart = run.sourceRange.upperBound
        }
        guard expectedGlyphStart == glyphs.count,
              expectedSourceStart == sourceUTF8Count
        else {
            throw LineLayoutError.invalidInput
        }
    }
}
