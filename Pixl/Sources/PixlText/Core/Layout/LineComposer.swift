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
        emptyLineMetrics: SFNT.Metrics,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>,
        units: Span<LineBreakUnit>,
        insertionGlyphs: Span<ShapingGlyph>,
        trailingToken: ShapedInsertionToken? = nil,
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
            let insertionStart = workspace.insertions.count
            let halfLeading = max(0, emptyLineMetrics.leading) * 0.5
            let naturalAbove = emptyLineMetrics.ascent + halfLeading
            let naturalBelow = emptyLineMetrics.descent + halfLeading
            let naturalHeight = naturalAbove + naturalBelow
            let resolvedHeight = lineHeight.resolve(natural: naturalHeight)
            let halfAdjustment = (resolvedHeight - naturalHeight) * 0.5
            let resolvedAbove = naturalAbove + halfAdjustment
            let resolvedBelow = naturalBelow + halfAdjustment
            let line = PositionedLine(
                positionRange: positionStart..<positionStart,
                insertionRange: insertionStart..<insertionStart,
                consumedSourceRange: 0..<0,
                consumedGlyphRange: 0..<0,
                visibleGlyphRange: 0..<0,
                breakKind: .mandatory,
                advance: 0,
                ascent: emptyLineMetrics.ascent,
                descent: emptyLineMetrics.descent,
                leading: max(0, emptyLineMetrics.leading),
                naturalAbove: naturalAbove,
                naturalBelow: naturalBelow,
                originX: horizontalOrigin,
                baselineY: lineTop + resolvedAbove,
                baselineOffset: resolvedAbove,
                typographicBounds: .init(
                    x: horizontalOrigin,
                    y: -emptyLineMetrics.ascent,
                    width: 0,
                    height: emptyLineMetrics.ascent + emptyLineMetrics.descent
                ),
                lineBounds: .init(
                    x: horizontalOrigin,
                    y: -resolvedAbove,
                    width: 0,
                    height: resolvedAbove + resolvedBelow
                ),
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
        let insertionStart = workspace.insertions.count
        let positionStart = workspace.positions.count
        let trailingAdvance = trailingToken.map {
            tokenAdvance($0, glyphs: insertionGlyphs)
        } ?? 0
        let contentMaximumWidth = max(0, maximumWidth - trailingAdvance)
        var lastFittingCandidate: Candidate? = trailingToken == nil ? nil : .init(
            sourceEnd: start.sourceOffset,
            glyphEnd: start.glyphIndex,
            visibleGlyphEnd: start.glyphIndex,
            positionCount: 0,
            breakKind: .allowed,
            advance: 0,
            ascent: 0,
            descent: 0,
            leading: 0,
            naturalAbove: 0,
            naturalBelow: 0,
            renderBounds: nil,
            insertionToken: nil,
            nextRunIndex: start.runIndex,
            nextOpportunityIndex: start.opportunityIndex,
            nextUnitIndex: start.unitIndex
        )

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
            if trailingToken != nil, visibleAdvance <= contentMaximumWidth {
                lastFittingCandidate = Candidate(
                    sourceEnd: clusterRange.upperBound,
                    glyphEnd: clusterEnd,
                    visibleGlyphEnd: visibleGlyphEnd,
                    positionCount: clusterEnd - start.glyphIndex,
                    breakKind: .allowed,
                    advance: visibleAdvance,
                    ascent: ascent,
                    descent: descent,
                    leading: leading,
                    naturalAbove: naturalAbove,
                    naturalBelow: naturalBelow,
                    renderBounds: renderBounds,
                    insertionToken: nil,
                    nextRunIndex: nextRunIndex,
                    nextOpportunityIndex: opportunityIndex,
                    nextUnitIndex: cluster.nextUnitIndex
                )
            }
            while opportunityIndex < opportunities.count,
                  opportunities[opportunityIndex].sourceOffset == clusterRange.upperBound {
                let opportunity = opportunities[opportunityIndex]
                let nextOpportunityIndex = opportunityIndex + 1
                let insertionToken: ShapedInsertionToken? = if trailingToken == nil,
                    opportunity.kind == .softHyphen || opportunity.kind == .automaticHyphen {
                    .init(
                        kind: .hyphen,
                        glyphRange: runs[runIndex].hyphenGlyphRange,
                        face: runs[runIndex].face,
                        size: runs[runIndex].size
                    )
                } else {
                    nil
                }
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
                    insertionToken: insertionToken,
                    nextRunIndex: nextRunIndex,
                    nextOpportunityIndex: nextOpportunityIndex,
                    nextUnitIndex: cluster.nextUnitIndex
                )

                let candidateAdvance = candidate.advance + (insertionToken.map {
                    tokenAdvance($0, glyphs: insertionGlyphs)
                } ?? 0)
                if candidateAdvance > contentMaximumWidth {
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
                        insertionStart: insertionStart,
                        insertionGlyphs: insertionGlyphs,
                        trailingToken: trailingToken,
                        registry: registry,
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
                        insertionStart: insertionStart,
                        insertionGlyphs: insertionGlyphs,
                        trailingToken: trailingToken,
                        registry: registry,
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
            insertionStart: insertionStart,
            insertionGlyphs: insertionGlyphs,
            trailingToken: trailingToken,
            registry: registry,
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
        let insertionToken: ShapedInsertionToken?
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
        insertionStart: Int,
        insertionGlyphs: Span<ShapingGlyph>,
        trailingToken: ShapedInsertionToken?,
        registry: borrowing SFNT.Registry,
        workspace: inout LineLayoutWorkspace
    ) -> LineComposition {
        let positionEnd = positionStart + candidate.positionCount
        let excess = workspace.positions.count - positionEnd
        workspace.positions.removeLast(excess)
        var advance = candidate.advance
        var ascent = candidate.ascent
        var descent = candidate.descent
        var naturalAbove = candidate.naturalAbove
        var naturalBelow = candidate.naturalBelow
        var renderBounds = candidate.renderBounds
        if let insertionToken = trailingToken ?? candidate.insertionToken {
            let metrics = insertionToken.face.metrics.scaled(to: insertionToken.size)
            let halfLeading = max(0, metrics.leading) * 0.5
            ascent = max(ascent, metrics.ascent)
            descent = max(descent, metrics.descent)
            naturalAbove = max(naturalAbove, metrics.ascent + halfLeading)
            naturalBelow = max(naturalBelow, metrics.descent + halfLeading)
            let scale = insertionToken.size / Float(insertionToken.face.metrics.unitsPerEm)
            var tokenPenX = candidate.advance
            for index in insertionToken.glyphRange {
                let glyph = insertionGlyphs[index]
                let position = PositionedGlyph(
                    x: tokenPenX + Float(glyph.xPlacement) * scale,
                    y: -Float(glyph.yPlacement) * scale
                )
                let glyphAdvance = Float(glyph.nominalXAdvance + glyph.xAdvance) * scale
                let bounds = registry.renderBounds(for: glyph.id, in: insertionToken.face).map {
                    PositionedLine.Bounds(
                        x: position.x + Float($0.xMin) * scale,
                        y: position.y - Float($0.yMax) * scale,
                        width: Float($0.xMax - $0.xMin) * scale,
                        height: Float($0.yMax - $0.yMin) * scale
                    )
                }
                if let bounds { renderBounds = union(renderBounds, bounds) }
                workspace.insertions.append(.init(
                    kind: insertionToken.kind,
                    glyphID: glyph.id,
                    face: insertionToken.face,
                    size: insertionToken.size,
                    sourceOffset: candidate.sourceEnd,
                    position: position,
                    advance: glyphAdvance,
                    renderBounds: bounds
                ))
                tokenPenX += glyphAdvance
            }
            advance = tokenPenX
        }
        let naturalHeight = naturalAbove + naturalBelow
        let resolvedHeight = lineHeight.resolve(natural: naturalHeight)
        let halfAdjustment = (resolvedHeight - naturalHeight) * 0.5
        let resolvedAbove = naturalAbove + halfAdjustment
        let resolvedBelow = naturalBelow + halfAdjustment
        let remainingWidth = max(0, maximumWidth - advance)
        let alignmentOffset: Float = switch alignment {
        case .leading: 0
        case .center: remainingWidth * 0.5
        case .trailing: remainingWidth
        }
        let offsetX = horizontalOrigin + alignmentOffset
        let line = PositionedLine(
            positionRange: positionStart..<positionEnd,
            insertionRange: insertionStart..<workspace.insertions.count,
            consumedSourceRange: start.sourceOffset..<candidate.sourceEnd,
            consumedGlyphRange: start.glyphIndex..<candidate.glyphEnd,
            visibleGlyphRange: start.glyphIndex..<candidate.visibleGlyphEnd,
            breakKind: candidate.breakKind,
            advance: advance,
            ascent: ascent,
            descent: descent,
            leading: max(0, naturalAbove + naturalBelow - ascent - descent),
            naturalAbove: naturalAbove,
            naturalBelow: naturalBelow,
            originX: offsetX,
            baselineY: lineTop + resolvedAbove,
            baselineOffset: resolvedAbove,
            typographicBounds: .init(
                x: offsetX,
                y: -ascent,
                width: advance,
                height: ascent + descent
            ),
            lineBounds: .init(
                x: offsetX,
                y: -resolvedAbove,
                width: advance,
                height: resolvedAbove + resolvedBelow
            ),
            renderBounds: renderBounds.map {
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

    private static func tokenAdvance(
        _ token: ShapedInsertionToken,
        glyphs: Span<ShapingGlyph>
    ) -> Float {
        let scale = token.size / Float(token.face.metrics.unitsPerEm)
        var result: Float = 0
        for index in token.glyphRange {
            let glyph = glyphs[index]
            result += Float(glyph.nominalXAdvance + glyph.xAdvance) * scale
        }
        return result
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
