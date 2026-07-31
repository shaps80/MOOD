enum LineComposer {
    static func start(
        sourceUTF8Count: Int,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>
    ) throws -> LineStart {
        try validate(
            sourceUTF8Count: sourceUTF8Count,
            glyphs: glyphs,
            runs: runs,
            opportunities: opportunities
        )
        return .init(
            sourceOffset: 0,
            glyphIndex: 0,
            runIndex: 0,
            opportunityIndex: 0,
            unitIndex: 0
        )
    }

    static func positionLine(
        from start: LineStart,
        lineTop: Float,
        sourceUTF8Count: Int,
        maximumWidth: Float,
        horizontalOrigin: Float,
        alignment: TextAlignment,
        lineHeight: LineHeight,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>,
        units: Span<LineBreakUnit>,
        registry: borrowing SFNT.Registry,
        workspace: inout LineLayoutWorkspace
    ) throws -> LineComposition {
        guard maximumWidth >= 0,
              maximumWidth.isFinite,
              horizontalOrigin.isFinite,
              lineTop.isFinite,
              lineHeight.isValid,
              start.sourceOffset >= 0,
              start.sourceOffset <= sourceUTF8Count,
              start.glyphIndex >= 0,
              start.glyphIndex <= glyphs.count,
              start.runIndex >= 0,
              start.runIndex <= runs.count,
              start.opportunityIndex >= 0,
              start.opportunityIndex <= opportunities.count,
              start.unitIndex >= 0,
              start.unitIndex <= units.count
        else {
            throw LineLayoutError.invalidInput
        }

        if glyphs.isEmpty {
            let positionStart = workspace.positions.count
            let line = PositionedLine(
                positionRange: positionStart..<positionStart,
                consumedSourceRange: 0..<0,
                consumedGlyphRange: 0..<0,
                visibleGlyphRange: 0..<0,
                breakKind: .mandatory,
                advance: 0,
                ascent: 0,
                descent: 0,
                leading: 0,
                naturalAbove: 0,
                naturalBelow: 0,
                originX: horizontalOrigin,
                baselineY: lineTop,
                baselineOffset: 0,
                typographicBounds: .init(x: horizontalOrigin, y: 0, width: 0, height: 0),
                lineBounds: .init(x: horizontalOrigin, y: 0, width: 0, height: 0),
                renderBounds: nil
            )
            return .init(line: line, next: nil)
        }

        guard start.glyphIndex < glyphs.count,
              start.runIndex < runs.count,
              start.opportunityIndex < opportunities.count,
              start.unitIndex < units.count,
              glyphs[start.glyphIndex].sourceRange.lowerBound == start.sourceOffset
        else {
            throw LineLayoutError.invalidInput
        }

        var penX: Float = 0
        var visibleAdvance: Float = 0
        var visibleGlyphEnd = start.glyphIndex
        var ascent: Float = 0
        var descent: Float = 0
        var leading: Float = 0
        var naturalAbove: Float = 0
        var naturalBelow: Float = 0
        var renderBounds: PositionedLine.Bounds?
        var runIndex = start.runIndex
        var measuredRunIndex: Int?
        var unitIndex = start.unitIndex
        var opportunityIndex = start.opportunityIndex
        var glyphIndex = start.glyphIndex
        var lastFittingCandidate: Candidate?
        let positionStart = workspace.positions.count

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
            let cluster = clusterAttributes(
                sourceRange: clusterRange,
                startingAt: unitIndex,
                units: units
            )
            let attributes = cluster.attributes

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
                if measuredRunIndex != runIndex {
                    let metrics = run.face.metrics.scaled(to: run.size)
                    let halfLeading = max(0, metrics.leading) * 0.5
                    ascent = max(ascent, metrics.ascent)
                    descent = max(descent, metrics.descent)
                    naturalAbove = max(naturalAbove, metrics.ascent + halfLeading)
                    naturalBelow = max(naturalBelow, metrics.descent + halfLeading)
                    leading = max(0, naturalAbove + naturalBelow - ascent - descent)
                    measuredRunIndex = runIndex
                }

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

            var nextRunIndex = runIndex
            while nextRunIndex < runs.count,
                  clusterEnd >= runs[nextRunIndex].glyphRange.upperBound {
                nextRunIndex += 1
            }

            while opportunityIndex < opportunities.count,
                  opportunities[opportunityIndex].sourceOffset < clusterRange.upperBound {
                opportunityIndex += 1
            }
            while opportunityIndex < opportunities.count,
                  opportunities[opportunityIndex].sourceOffset == clusterRange.upperBound {
                let opportunity = opportunities[opportunityIndex]
                let nextOpportunityIndex = opportunityIndex + 1
                let candidate = Candidate(
                    sourceEnd: opportunity.sourceOffset,
                    glyphEnd: clusterEnd,
                    visibleGlyphEnd: visibleGlyphEnd,
                    positionCount: clusterEnd - start.glyphIndex,
                    breakKind: opportunity.kind,
                    advance: visibleAdvance,
                    ascent: ascent,
                    descent: descent,
                    leading: leading,
                    naturalAbove: naturalAbove,
                    naturalBelow: naturalBelow,
                    renderBounds: renderBounds,
                    nextRunIndex: nextRunIndex,
                    nextOpportunityIndex: nextOpportunityIndex,
                    nextUnitIndex: cluster.nextUnitIndex
                )

                if candidate.advance > maximumWidth {
                    return finish(
                        lastFittingCandidate ?? candidate,
                        start: start,
                        positionStart: positionStart,
                        lineTop: lineTop,
                        horizontalOrigin: horizontalOrigin,
                        maximumWidth: maximumWidth,
                        alignment: alignment,
                        sourceUTF8Count: sourceUTF8Count,
                        glyphCount: glyphs.count,
                        lineHeight: lineHeight,
                        workspace: &workspace
                    )
                }
                if opportunity.kind == .mandatory {
                    return finish(
                        candidate,
                        start: start,
                        positionStart: positionStart,
                        lineTop: lineTop,
                        horizontalOrigin: horizontalOrigin,
                        maximumWidth: maximumWidth,
                        alignment: alignment,
                        sourceUTF8Count: sourceUTF8Count,
                        glyphCount: glyphs.count,
                        lineHeight: lineHeight,
                        workspace: &workspace
                    )
                }
                lastFittingCandidate = candidate
                opportunityIndex = nextOpportunityIndex
            }

            unitIndex = cluster.nextUnitIndex
            glyphIndex = clusterEnd
        }

        guard let candidate = lastFittingCandidate else {
            throw LineLayoutError.invalidInput
        }
        return finish(
            candidate,
            start: start,
            positionStart: positionStart,
            lineTop: lineTop,
            horizontalOrigin: horizontalOrigin,
            maximumWidth: maximumWidth,
            alignment: alignment,
            sourceUTF8Count: sourceUTF8Count,
            glyphCount: glyphs.count,
            lineHeight: lineHeight,
            workspace: &workspace
        )
    }

    private struct Candidate {
        let sourceEnd: Int
        let glyphEnd: Int
        let visibleGlyphEnd: Int
        let positionCount: Int
        let breakKind: LineBreakKind
        let advance: Float
        let ascent: Float
        let descent: Float
        let leading: Float
        let naturalAbove: Float
        let naturalBelow: Float
        let renderBounds: PositionedLine.Bounds?
        let nextRunIndex: Int
        let nextOpportunityIndex: Int
        let nextUnitIndex: Int
    }

    private struct ClusterAttributes {
        let isVisible: Bool
        let consumesAdvance: Bool
    }

    private struct Cluster {
        let attributes: ClusterAttributes
        let nextUnitIndex: Int
    }

    private static func clusterAttributes(
        sourceRange: Range<Int>,
        startingAt start: Int,
        units: Span<LineBreakUnit>
    ) -> Cluster {
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
            attributes: .init(
                isVisible: hasVisibleScalar,
                consumesAdvance: hasVisibleScalar || hasSpace
            ),
            nextUnitIndex: index
        )
    }

    private static func isNonRendering(_ unit: LineBreakUnit) -> Bool {
        if unit.scalar == 0x00AD || unit.scalar == 0x2060 { return true }
        return [.bk, .cr, .lf, .nl, .zw, .wj].contains(unit.raw)
    }

    private static func finish(
        _ candidate: Candidate,
        start: LineStart,
        positionStart: Int,
        lineTop: Float,
        horizontalOrigin: Float,
        maximumWidth: Float,
        alignment: TextAlignment,
        sourceUTF8Count: Int,
        glyphCount: Int,
        lineHeight: LineHeight,
        workspace: inout LineLayoutWorkspace
    ) -> LineComposition {
        let positionEnd = positionStart + candidate.positionCount
        let excess = workspace.positions.count - positionEnd
        workspace.positions.removeLast(excess)
        let naturalHeight = candidate.naturalAbove + candidate.naturalBelow
        let resolvedHeight = lineHeight.resolve(natural: naturalHeight)
        let halfAdjustment = (resolvedHeight - naturalHeight) * 0.5
        let resolvedAbove = candidate.naturalAbove + halfAdjustment
        let resolvedBelow = candidate.naturalBelow + halfAdjustment
        let remainingWidth = max(0, maximumWidth - candidate.advance)
        let alignmentOffset: Float = switch alignment {
        case .leading: 0
        case .center: remainingWidth * 0.5
        case .trailing: remainingWidth
        }
        let offsetX = horizontalOrigin + alignmentOffset
        let line = PositionedLine(
            positionRange: positionStart..<positionEnd,
            consumedSourceRange: start.sourceOffset..<candidate.sourceEnd,
            consumedGlyphRange: start.glyphIndex..<candidate.glyphEnd,
            visibleGlyphRange: start.glyphIndex..<candidate.visibleGlyphEnd,
            breakKind: candidate.breakKind,
            advance: candidate.advance,
            ascent: candidate.ascent,
            descent: candidate.descent,
            leading: candidate.leading,
            naturalAbove: candidate.naturalAbove,
            naturalBelow: candidate.naturalBelow,
            originX: offsetX,
            baselineY: lineTop + resolvedAbove,
            baselineOffset: resolvedAbove,
            typographicBounds: .init(
                x: offsetX,
                y: -candidate.ascent,
                width: candidate.advance,
                height: candidate.ascent + candidate.descent
            ),
            lineBounds: .init(
                x: offsetX,
                y: -resolvedAbove,
                width: candidate.advance,
                height: resolvedAbove + resolvedBelow
            ),
            renderBounds: candidate.renderBounds.map {
                .init(
                    x: $0.x + offsetX,
                    y: $0.y,
                    width: $0.width,
                    height: $0.height
                )
            }
        )
        let isComplete = candidate.sourceEnd == sourceUTF8Count
            && candidate.glyphEnd == glyphCount
        let next: LineStart? = isComplete ? nil : .init(
            sourceOffset: candidate.sourceEnd,
            glyphIndex: candidate.glyphEnd,
            runIndex: candidate.nextRunIndex,
            opportunityIndex: candidate.nextOpportunityIndex,
            unitIndex: candidate.nextUnitIndex
        )
        return .init(line: line, next: next)
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
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>
    ) throws {
        guard sourceUTF8Count >= 0,
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
