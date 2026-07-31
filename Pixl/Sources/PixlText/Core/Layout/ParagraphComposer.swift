enum ParagraphComposer {
    static func positionParagraphs(
        sourceUTF8Count: Int,
        constraints: LayoutConstraints,
        lineHeight: LineHeight,
        baseMetrics: SFNT.Metrics,
        styles: Span<ParagraphStyle>,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>,
        units: Span<LineBreakUnit>,
        registry: borrowing SFNT.Registry,
        workspace: inout LineLayoutWorkspace
    ) throws -> PositionedLayout {
        guard constraints.isValid,
              lineHeight.isValid,
              baseMetrics.ascent >= 0,
              baseMetrics.ascent.isFinite,
              baseMetrics.descent >= 0,
              baseMetrics.descent.isFinite,
              baseMetrics.leading.isFinite,
              !styles.isEmpty
        else {
            throw LineLayoutError.invalidInput
        }

        workspace.removeAll()
        var next: LineStart? = try LineComposer.start(
            sourceUTF8Count: sourceUTF8Count,
            glyphs: glyphs,
            runs: runs,
            opportunities: opportunities
        )
        var lineTop: Float = 0
        var paragraphLineStart = 0
        var paragraphSourceStart = 0
        var paragraphBounds: PositionedLine.Bounds?
        var paragraphRenderBounds: PositionedLine.Bounds?
        var firstBaselineY: Float = 0
        var paragraphIndex = 0
        var isFirstLine = true

        while let lineStart = next {
            guard paragraphIndex < styles.count else {
                throw LineLayoutError.invalidInput
            }
            let style = styles[paragraphIndex]
            guard style.isValid else { throw LineLayoutError.invalidInput }
            if isFirstLine {
                lineTop += style.spacing.paragraphBefore
            }
            var leading = style.indentation.leading
            var trailing = style.indentation.trailing
            if isFirstLine {
                switch style.alignment {
                case .leading:
                    leading += style.indentation.firstLine
                case .center:
                    break
                case .trailing:
                    trailing += style.indentation.firstLine
                }
            }
            let availableWidth = max(
                0,
                constraints.width - leading - trailing
            )
            let composition = try LineComposer.positionLine(
                from: lineStart,
                lineTop: lineTop,
                sourceUTF8Count: sourceUTF8Count,
                maximumWidth: availableWidth,
                horizontalOrigin: leading,
                alignment: style.alignment,
                lineHeight: lineHeight,
                emptyLineMetrics: baseMetrics,
                glyphs: glyphs,
                runs: runs,
                opportunities: opportunities,
                units: units,
                registry: registry,
                workspace: &workspace
            )
            let line = composition.line
            let lineIndex = workspace.lines.count
            if lineIndex == paragraphLineStart {
                firstBaselineY = line.baselineY
            }
            paragraphBounds = union(paragraphBounds, documentBounds(
                line.lineBounds,
                baselineY: line.baselineY
            ))
            if let renderBounds = line.renderBounds {
                paragraphRenderBounds = union(paragraphRenderBounds, documentBounds(
                    renderBounds,
                    baselineY: line.baselineY
                ))
            }
            workspace.lines.append(line)
            next = composition.next

            let endsParagraph = line.breakKind == .mandatory || next == nil
            if endsParagraph {
                workspace.paragraphs.append(.init(
                    lineRange: paragraphLineStart..<(lineIndex + 1),
                    consumedSourceRange: paragraphSourceStart..<line.consumedSourceRange.upperBound,
                    bounds: paragraphBounds!,
                    renderBounds: paragraphRenderBounds,
                    firstBaselineY: firstBaselineY,
                    lastBaselineY: line.baselineY
                ))
                paragraphLineStart = lineIndex + 1
                paragraphSourceStart = line.consumedSourceRange.upperBound
                paragraphBounds = nil
                paragraphRenderBounds = nil
                paragraphIndex += 1
                isFirstLine = true
            } else {
                isFirstLine = false
            }

            let reachedLineLimit = constraints.lines.maximum != 0
                && UInt(workspace.lines.count) >= constraints.lines.maximum
            if reachedLineLimit, next != nil {
                if !endsParagraph {
                    workspace.paragraphs.append(.init(
                        lineRange: paragraphLineStart..<(lineIndex + 1),
                        consumedSourceRange: (
                            paragraphSourceStart..<line.consumedSourceRange.upperBound
                        ),
                        bounds: paragraphBounds!,
                        renderBounds: paragraphRenderBounds,
                        firstBaselineY: firstBaselineY,
                        lastBaselineY: line.baselineY
                    ))
                }
                return positionedLayout(
                    status: .overflow,
                    constraints: constraints,
                    lineHeight: lineHeight,
                    baseMetrics: baseMetrics,
                    workspace: workspace
                )
            }

            guard next != nil else { break }
            lineTop += line.lineBounds.height
            lineTop += endsParagraph
                ? style.spacing.paragraphAfter
                : style.spacing.lineSpacing
        }
        guard paragraphIndex == styles.count else {
            throw LineLayoutError.invalidInput
        }
        return positionedLayout(
            status: .complete,
            constraints: constraints,
            lineHeight: lineHeight,
            baseMetrics: baseMetrics,
            workspace: workspace
        )
    }

    private static func positionedLayout(
        status: LayoutStatus,
        constraints: LayoutConstraints,
        lineHeight: LineHeight,
        baseMetrics: SFNT.Metrics,
        workspace: borrowing LineLayoutWorkspace
    ) -> PositionedLayout {
        let lineCount = UInt(workspace.lines.count)
        let reservedLineCount = constraints.lines.minimum > lineCount
            ? constraints.lines.minimum - lineCount
            : 0
        let naturalBaseHeight = baseMetrics.ascent
            + baseMetrics.descent
            + max(0, baseMetrics.leading)
        let reservedLineHeight = lineHeight.resolve(natural: naturalBaseHeight)
        let contentHeight: Float
        if workspace.paragraphs.count > 0 {
            let bounds = workspace.paragraphs[workspace.paragraphs.count - 1].bounds
            contentHeight = bounds.y + bounds.height
        } else {
            contentHeight = 0
        }
        return .init(
            status: status,
            bounds: .init(
                x: 0,
                y: 0,
                width: constraints.width,
                height: contentHeight + Float(reservedLineCount) * reservedLineHeight
            ),
            reservedLineCount: reservedLineCount
        )
    }

    private static func documentBounds(
        _ bounds: PositionedLine.Bounds,
        baselineY: Float
    ) -> PositionedLine.Bounds {
        .init(
            x: bounds.x,
            y: baselineY + bounds.y,
            width: bounds.width,
            height: bounds.height
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
}
